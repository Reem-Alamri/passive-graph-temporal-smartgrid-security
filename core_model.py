"""Minimal, source-derived PyTorch core for the three-task smart-grid model.

The module retains the parameter-bearing submodules of the supplied final
model implementation, including inactive legacy auxiliary outputs, so that
reported parameter accounting is not changed by selectively deleting heads.
It does not include data generation, splitting, training scripts, or weights.

The dense line-attention path follows IEEE-14/118 source stages; the sparse
path follows the IEEE-300 source stage. Both enforce endpoint-only attention.
"""
from __future__ import annotations

import copy
import numpy as np
import torch
from torch import nn
from torch.nn import functional as F


class GraphConvolution(nn.Module):
    def __init__(self, input_dim: int, output_dim: int):
        super().__init__()
        self.linear = nn.Linear(input_dim, output_dim)

    def forward(self, x: torch.Tensor, adjacency: torch.Tensor) -> torch.Tensor:
        aggregated = torch.einsum("nm,btmf->btnf", adjacency, x)
        return self.linear(aggregated)


class LocalLineAttentionDense(nn.Module):
    """Dense masked attention from the IEEE-14/118 source implementation."""
    def __init__(self, hidden_dim: int, heads: int, dropout: float):
        super().__init__()
        self.attention = nn.MultiheadAttention(
            embed_dim=hidden_dim, num_heads=heads, dropout=dropout, batch_first=True
        )
        self.norm_1 = nn.LayerNorm(hidden_dim)
        self.feedforward = nn.Sequential(
            nn.Linear(hidden_dim, 2 * hidden_dim), nn.GELU(),
            nn.Dropout(dropout), nn.Linear(2 * hidden_dim, hidden_dim)
        )
        self.norm_2 = nn.LayerNorm(hidden_dim)

    def forward(self, x: torch.Tensor, blocked_mask: torch.Tensor) -> torch.Tensor:
        attended, _ = self.attention(x, x, x, attn_mask=blocked_mask, need_weights=False)
        x = self.norm_1(x + attended)
        return self.norm_2(x + self.feedforward(x))


class LocalLineAttentionSparse(nn.Module):
    """Sparse shared-endpoint attention from the IEEE-300 source implementation."""
    def __init__(self, hidden_dim: int, heads: int, dropout: float, blocked_mask):
        super().__init__()
        if hidden_dim % heads:
            raise ValueError("hidden_dim must be divisible by heads")
        self.hidden_dim = int(hidden_dim)
        self.heads = int(heads)
        self.head_dim = hidden_dim // heads
        self.dropout = float(dropout)
        self.scale = self.head_dim ** (-0.5)
        self.qkv_projection = nn.Linear(hidden_dim, 3 * hidden_dim, bias=True)
        self.output_projection = nn.Linear(hidden_dim, hidden_dim, bias=True)
        self.norm_1 = nn.LayerNorm(hidden_dim)
        self.feedforward = nn.Sequential(
            nn.Linear(hidden_dim, 2 * hidden_dim), nn.GELU(),
            nn.Dropout(dropout), nn.Linear(2 * hidden_dim, hidden_dim)
        )
        self.norm_2 = nn.LayerNorm(hidden_dim)
        allowed = ~np.asarray(blocked_mask, dtype=bool)
        n_branches = allowed.shape[0]
        if allowed.shape != (n_branches, n_branches) or not np.all(np.diag(allowed)):
            raise ValueError("Invalid line-neighborhood mask; each line must attend to itself")
        neighbor_lists = [np.flatnonzero(allowed[k]).astype(np.int64) for k in range(n_branches)]
        max_neighbors = max(len(x) for x in neighbor_lists)
        neighbor_index = np.zeros((n_branches, max_neighbors), dtype=np.int64)
        neighbor_valid = np.zeros((n_branches, max_neighbors), dtype=bool)
        for k, indexes in enumerate(neighbor_lists):
            n = len(indexes)
            neighbor_index[k, :n] = indexes
            neighbor_valid[k, :n] = True
            if n < max_neighbors:
                neighbor_index[k, n:] = k
        self.register_buffer("neighbor_index", torch.as_tensor(neighbor_index, dtype=torch.long))
        self.register_buffer("neighbor_valid", torch.as_tensor(neighbor_valid, dtype=torch.bool))
        self.max_neighbors = int(max_neighbors)
        self.mean_neighbors = float(np.mean([len(x) for x in neighbor_lists]))
        nn.init.xavier_uniform_(self.qkv_projection.weight)
        nn.init.zeros_(self.qkv_projection.bias)
        nn.init.xavier_uniform_(self.output_projection.weight)
        nn.init.zeros_(self.output_projection.bias)

    def forward(self, x: torch.Tensor, blocked_mask: torch.Tensor) -> torch.Tensor:
        del blocked_mask
        batch_size, line_count, hidden_dim = x.shape
        if line_count != self.neighbor_index.shape[0]:
            raise RuntimeError("Line count differs from the neighborhood mask")
        query, key, value = torch.chunk(self.qkv_projection(x), 3, dim=-1)

        def split_heads(tensor):
            return tensor.reshape(batch_size, line_count, self.heads, self.head_dim).permute(0, 2, 1, 3)

        query, key, value = map(split_heads, (query, key, value))
        local_key = key[:, :, self.neighbor_index, :]
        local_value = value[:, :, self.neighbor_index, :]
        attention_score = (query.unsqueeze(-2).float() * local_key.float()).sum(-1) * self.scale
        attention_score = attention_score.masked_fill(~self.neighbor_valid[None, None, :, :], float("-inf"))
        attention_weight = torch.softmax(attention_score, -1).to(dtype=local_value.dtype)
        attention_weight = F.dropout(attention_weight, p=self.dropout, training=self.training)
        attended = (attention_weight.unsqueeze(-1) * local_value).sum(-2)
        attended = attended.permute(0, 2, 1, 3).reshape(batch_size, line_count, hidden_dim)
        attended = self.output_projection(attended)
        x = self.norm_1(x + attended)
        return self.norm_2(x + self.feedforward(x))


class ConfigurableRecurrentEnrichedMTL(nn.Module):
    """Final-model class, refactored to receive topology instead of notebook globals.

    node_input_dim and branch_input_dim describe *preprocessed* features;
    source/target indexes and blocked-line mask refer to the same line ordering.

    The original source instantiates legacy auxiliary heads. They are preserved
    here for state-dict/parameter accounting consistency, but the reported
    three-task loss uses only detection, cyber_bus, and final_line outputs.
    """
    def __init__(self, node_input_dim: int, branch_input_dim: int,
                 source_index, target_index, physics_feature_indices,
                 line_blocked_mask, n_buses: int, *,
                 attention_backend: str = "dense", dropout: float = 0.20):
        super().__init__()
        source_index = np.asarray(source_index, dtype=np.int64)
        target_index = np.asarray(target_index, dtype=np.int64)
        physics_feature_indices = np.asarray(physics_feature_indices, dtype=np.int64)
        line_blocked_mask = np.asarray(line_blocked_mask, dtype=bool)
        self.n_buses = int(n_buses)
        self.n_branches = int(len(source_index))
        if not len(target_index) == self.n_branches:
            raise ValueError("Each source endpoint needs a matching target endpoint")
        if line_blocked_mask.shape != (self.n_branches, self.n_branches):
            raise ValueError("Expected [L,L] blocked line-attention mask")
        if not (np.all(source_index >= 0) and np.all(target_index >= 0)
                and np.all(source_index < n_buses) and np.all(target_index < n_buses)):
            raise ValueError("Line endpoints must be valid zero-based bus indexes")
        if len(physics_feature_indices) != 16:
            raise ValueError("Expected 16 physics-branch feature indexes")
        if attention_backend not in {"dense", "sparse"}:
            raise ValueError("attention_backend must be 'dense' or 'sparse'")
        self.recurrent_type = "gru"
        self.line_identity_scale = 0.0
        self.node_projection = nn.Sequential(nn.Linear(node_input_dim, 64), nn.LayerNorm(64), nn.GELU())
        self.graph_1 = GraphConvolution(64, 64)
        self.graph_2 = GraphConvolution(64, 64)
        self.node_norm_1 = nn.LayerNorm(64)
        self.node_norm_2 = nn.LayerNorm(64)
        self.node_recurrent = nn.GRU(64, 64, batch_first=True)
        self.edge_projection = nn.Sequential(
            nn.Linear(branch_input_dim + 128, 64), nn.LayerNorm(64),
            nn.GELU(), nn.Dropout(dropout)
        )
        self.line_identity = nn.Embedding(self.n_branches, 64)
        self.line_identity.weight.requires_grad_(False)
        self.branch_recurrent = nn.GRU(64, 64, batch_first=True)
        self.local_line_attention = (
            LocalLineAttentionDense(64, heads=4, dropout=dropout)
            if attention_backend == "dense" else
            LocalLineAttentionSparse(64, heads=4, dropout=dropout, blocked_mask=line_blocked_mask)
        )
        self.physics_projection = nn.Sequential(
            nn.Linear(16, 64), nn.LayerNorm(64), nn.GELU(), nn.Dropout(dropout)
        )
        self.global_input_norm = nn.LayerNorm(256)
        self.global_recurrent = nn.GRU(256, 128, batch_first=True)
        self.detection_head = nn.Sequential(
            nn.Linear(128, 128), nn.GELU(), nn.Dropout(dropout), nn.Linear(128, 5)
        )
        # Retained from source model class for parameter-count compatibility.
        # The loss below does not optimize these auxiliary outputs.
        self.physical_activity_head = nn.Linear(128, 1)
        self.cyber_activity_head = nn.Linear(128, 1)
        self.count_head = nn.Linear(128, 3)
        self.base_line_head = nn.Sequential(
            nn.Linear(192, 64), nn.GELU(), nn.Dropout(dropout), nn.Linear(64, 1)
        )
        self.physics_prior_head = nn.Sequential(nn.Linear(64, 32), nn.GELU(), nn.Linear(32, 1))
        self.physics_residual_head = nn.Sequential(
            nn.Linear(256, 64), nn.GELU(), nn.Dropout(dropout), nn.Linear(64, 1)
        )
        self.physical_bus_head = nn.Sequential(nn.Linear(192, 64), nn.GELU(), nn.Linear(64, 1))
        self.cyber_bus_head = copy.deepcopy(self.physical_bus_head)
        self.cyber_branch_head = nn.Sequential(nn.Linear(192, 64), nn.GELU(), nn.Linear(64, 1))
        self.node_effect_head = nn.Linear(192, 2)
        self.branch_effect_head = nn.Linear(192, 2)
        self.prior_logit_scale = nn.Parameter(torch.tensor(-2.0))
        self.residual_logit_scale = nn.Parameter(torch.tensor(-2.0))
        nn.init.zeros_(self.physics_prior_head[-1].weight)
        nn.init.zeros_(self.physics_prior_head[-1].bias)
        nn.init.zeros_(self.physics_residual_head[-1].weight)
        nn.init.zeros_(self.physics_residual_head[-1].bias)
        self.register_buffer("source_index", torch.as_tensor(source_index, dtype=torch.long))
        self.register_buffer("target_index", torch.as_tensor(target_index, dtype=torch.long))
        self.register_buffer("physics_feature_index", torch.as_tensor(physics_feature_indices, dtype=torch.long))
        self.register_buffer("line_blocked_mask", torch.as_tensor(line_blocked_mask, dtype=torch.bool))

    def forward(self, x_node: torch.Tensor, x_branch: torch.Tensor,
                adjacency: torch.Tensor) -> dict[str, torch.Tensor]:
        batch_size, sequence_length, n_buses, _ = x_node.shape
        n_branches = x_branch.shape[2]
        if n_buses != self.n_buses or n_branches != self.n_branches:
            raise ValueError("Input topology dimensions do not match model configuration")
        node = self.node_projection(x_node)
        graph = F.gelu(self.node_norm_1(self.graph_1(node, adjacency) + node))
        graph = F.gelu(self.node_norm_2(self.graph_2(graph, adjacency) + graph))
        node_temporal = graph.permute(0, 2, 1, 3).reshape(batch_size * n_buses, sequence_length, -1)
        node_temporal, _ = self.node_recurrent(node_temporal)
        node_temporal = node_temporal.reshape(batch_size, n_buses, sequence_length, -1).permute(0, 2, 1, 3)
        source = node_temporal[:, :, self.source_index, :]
        target = node_temporal[:, :, self.target_index, :]
        endpoint_sum = source + target
        endpoint_difference = torch.abs(source - target)
        edge = self.edge_projection(torch.cat([x_branch, endpoint_sum, endpoint_difference], dim=-1))
        edge_temporal = edge.permute(0, 2, 1, 3).reshape(batch_size * n_branches, sequence_length, -1)
        edge_temporal, _ = self.branch_recurrent(edge_temporal)
        edge_temporal = edge_temporal.reshape(batch_size, n_branches, sequence_length, -1).permute(0, 2, 1, 3)
        flat_lines = edge_temporal.reshape(batch_size * sequence_length, n_branches, -1)
        flat_lines = self.local_line_attention(flat_lines, self.line_blocked_mask)
        edge_temporal = flat_lines.reshape(batch_size, sequence_length, n_branches, -1)
        physics = x_branch.index_select(dim=-1, index=self.physics_feature_index)
        physics_embedding = self.physics_projection(physics)
        node_mean = node_temporal.mean(dim=2)
        node_max = node_temporal.max(dim=2).values
        edge_mean = edge_temporal.mean(dim=2)
        edge_max = edge_temporal.max(dim=2).values
        global_input = self.global_input_norm(torch.cat([node_mean, node_max, edge_mean, edge_max], dim=-1))
        global_sequence, _ = self.global_recurrent(global_input)
        detection_logits = self.detection_head(global_sequence)
        physical_activity_logits = self.physical_activity_head(global_sequence).squeeze(-1)
        cyber_activity_logits = self.cyber_activity_head(global_sequence).squeeze(-1)
        global_line = global_sequence[:, :, None, :].expand(-1, -1, n_branches, -1)
        global_bus = global_sequence[:, :, None, :].expand(-1, -1, n_buses, -1)
        line_context = torch.cat([edge_temporal, global_line], dim=-1)
        physics_context = torch.cat([edge_temporal, physics_embedding, global_line], dim=-1)
        bus_context = torch.cat([node_temporal, global_bus], dim=-1)
        base_line_logits = self.base_line_head(line_context).squeeze(-1)
        physics_prior = self.physics_prior_head(physics_embedding).squeeze(-1)
        physics_residual = self.physics_residual_head(physics_context).squeeze(-1)
        adapted_logits = (base_line_logits + torch.sigmoid(self.prior_logit_scale) * physics_prior
                          + torch.sigmoid(self.residual_logit_scale) * physics_residual)
        # Final configurations use no physical-activity gate.
        final_line_logits = adapted_logits.float()
        physical_probability = torch.sigmoid(physical_activity_logits)
        physical_gate = 0.05 + 0.95 * physical_probability
        return {
            "detection_logits": detection_logits,
            "physical_activity_logits": physical_activity_logits,
            "cyber_activity_logits": cyber_activity_logits,
            "count_logits": self.count_head(global_sequence),
            "base_line_logits": base_line_logits,
            "final_line_logits": final_line_logits,
            "physical_gate": physical_gate,
            "physical_bus_logits": self.physical_bus_head(bus_context).squeeze(-1),
            "cyber_bus_logits": self.cyber_bus_head(bus_context).squeeze(-1),
            "cyber_branch_logits": self.cyber_branch_head(line_context).squeeze(-1),
            "node_effect": self.node_effect_head(bus_context),
            "branch_effect": self.branch_effect_head(line_context),
        }


def three_task_loss(outputs: dict[str, torch.Tensor], batch: dict[str, torch.Tensor],
                    eligible_line_mask: torch.Tensor, line_pos_weight: torch.Tensor,
                    cyber_bus_pos_weight: torch.Tensor,
                    detection_class_weight: torch.Tensor | None = None,
                    physical_step_loss_boost: float = 2.0,
                    ranking_margin: float = 0.25):
    """Three-task objective in Equation (18), with Train-derived weights supplied.

    Required batch fields: y_class [B,T], y_line [B,T,L], y_cyber_bus [B,T,N].
    This mirrors the original loss implementation, not a new training recipe.
    """
    y_class, y_line, y_bus = batch["y_class"], batch["y_line"], batch["y_cyber_bus"]
    b, t = y_class.shape
    eligible = eligible_line_mask.to(y_line.device, dtype=y_line.dtype).view(1, 1, -1)
    step_weight = torch.linspace(0.1, 1.0, t, device=y_class.device).view(1, t).expand(b, -1).clone()
    transition = torch.zeros_like(y_class, dtype=torch.bool)
    transition[:, 1:] = y_class[:, 1:] != y_class[:, :-1]
    step_weight *= 1.0 + transition.float()
    step_weight[:, -1] *= 1.5

    def masked_mean(values, weights):
        return (values * weights).sum() / weights.sum().clamp_min(1.0)

    det_raw = F.cross_entropy(
        outputs["detection_logits"].reshape(-1, 5), y_class.reshape(-1),
        weight=detection_class_weight, reduction="none"
    ).reshape_as(y_class)
    l_det = masked_mean(det_raw, step_weight)
    line_raw = F.binary_cross_entropy_with_logits(
        outputs["final_line_logits"], y_line,
        pos_weight=line_pos_weight, reduction="none"
    )
    physical_step = (y_line.sum(dim=-1) > 0).float()
    line_weight = (step_weight[:, :, None] * eligible
                   * (1.0 + physical_step_loss_boost * physical_step[:, :, None]))
    l_line = masked_mean(line_raw, line_weight)
    bus_raw = F.binary_cross_entropy_with_logits(
        outputs["cyber_bus_logits"], y_bus,
        pos_weight=cyber_bus_pos_weight, reduction="none"
    )
    l_bus = masked_mean(bus_raw, step_weight[:, :, None].expand_as(bus_raw))

    line_prob = torch.sigmoid(outputs["final_line_logits"])
    no_physical = (y_line.sum(dim=-1) == 0).float()
    active_prob = line_prob * eligible
    mean_prob = active_prob.sum(dim=-1) / eligible.sum().clamp_min(1.0)
    max_prob = line_prob.masked_fill(eligible <= 0, -1.0).max(dim=-1).values
    l_fa = ((mean_prob.square() + 2.0 * F.relu(max_prob - 0.1).square())
            * no_physical).sum() / no_physical.sum().clamp_min(1.0)

    positive = (y_line > 0.5) & (eligible > 0)
    negative = (y_line <= 0.5) & (eligible > 0)
    valid = positive.any(dim=-1) & negative.any(dim=-1)
    if bool(valid.any()):
        weakest_pos = outputs["final_line_logits"].masked_fill(~positive, float("inf")).min(dim=-1).values
        strongest_neg = outputs["final_line_logits"].masked_fill(~negative, float("-inf")).max(dim=-1).values
        l_rank = F.softplus(ranking_margin + strongest_neg[valid] - weakest_pos[valid]).mean()
    else:
        l_rank = l_det.new_zeros(())

    total = l_det + l_bus + l_line + 0.10 * l_fa + 0.18 * l_rank
    return total, {"detection": l_det, "bus": l_bus, "line": l_line,
                   "false_alarm": l_fa, "ranking": l_rank}
