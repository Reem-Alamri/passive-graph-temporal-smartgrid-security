clear;
_sg_script_dir = fileparts(mfilename('fullpath'));
addpath(_sg_script_dir, genpath(fullfile(_sg_script_dir, '..', 'shared_functions')));


CASE_FILE        = 'case14';
CASE_TAG         = 'ieee14';

NUM_CLASSES      = 5;
CLASS_NAMES      = ["NORMAL","FDIA","TLO","CCPA_FULL","CCPA_PARTIAL"];

SMOKE_TEST = false;

SMOKE_BASE_STATES = 5;
FULL_BASE_STATES  = 300;

if SMOKE_TEST
    NUM_BASE_STATES = SMOKE_BASE_STATES;
else
    NUM_BASE_STATES = FULL_BASE_STATES;
end

RUNS_PER_CLASS = NUM_BASE_STATES;
NUM_RUNS_TARGET = NUM_BASE_STATES * NUM_CLASSES;

if ~(isnumeric(NUM_BASE_STATES) && isreal(NUM_BASE_STATES) && ...
        isscalar(NUM_BASE_STATES) && isfinite(NUM_BASE_STATES) && ...
        NUM_BASE_STATES == fix(NUM_BASE_STATES) && NUM_BASE_STATES >= 3)
    error(['Invalid NUM_BASE_STATES before run-plan construction. ' ...
           'class=%s, size=%s, value=%s. Expected one finite integer >= 3.'], ...
          class(NUM_BASE_STATES), mat2str(size(NUM_BASE_STATES)), ...
          mat2str(NUM_BASE_STATES));
end
NUM_BASE_STATES = double(NUM_BASE_STATES);

assert(RUNS_PER_CLASS == NUM_BASE_STATES, ...
    'RUNS_PER_CLASS and NUM_BASE_STATES must remain identical.');
assert(NUM_RUNS_TARGET == NUM_BASE_STATES * NUM_CLASSES, ...
    'NUM_RUNS_TARGET is inconsistent with the counterfactual bundle design.');

T_TOTAL          = 219;
T_WIN            = 20;
STRIDE           = 1;

CCPA_EQUATION_MODE = 'chen2022_eq4_eq6';
CCPA_MASKING_MODE  = 'paper_faithful';

FDIA_CONSTRUCTION_MODE = 'canonical_hc';
FDIA_VERSION = 'canonical_hc_nonzero_non_slack_v1';
FDIA_REFERENCE_TITLE = ...
    'False Data Injection Attacks against State Estimation in Electric Power Grids';

OUTAGE_SAMPLING_MODE = 'coverage_controlled_uniform';
MAX_OUTAGED_LINES_PRIMARY = 2;

assert(strcmp(char(CCPA_EQUATION_MODE), 'chen2022_eq4_eq6'), ...
    'The final primary generator requires Chen2022 equations (4) and (6).');
assert(strcmp(char(FDIA_CONSTRUCTION_MODE), 'canonical_hc'), ...
    'The final primary generator requires canonical standalone FDIA: a = H*c.');
assert(strcmp(char(CCPA_MASKING_MODE), 'paper_faithful'), ...
    'Do not change CCPA_MASKING_MODE in the final primary generator.');
assert(strcmp(char(OUTAGE_SAMPLING_MODE), 'coverage_controlled_uniform'), ...
    'Unexpected outage-sampling mode.');
assert(MAX_OUTAGED_LINES_PRIMARY == 2, ...
    'The primary dataset must use at most two simultaneous line outages.');

if SMOKE_TEST
    DATASET_VARIANT_TAG = '_coverage_uniform_enriched_v7_fdia_canonical_hc_smoke';
else
    DATASET_VARIANT_TAG = '_coverage_uniform_enriched_v7_fdia_canonical_hc';
end
OUTAGE_SAMPLING_VERSION = 'counterfactual_balanced_anchor_uniform_pair_max2_v2';
COUNTERFACTUAL_VERSION = 'paired_five_class_base_state_v1';
FEATURE_SCHEMA_VERSION = 'dc_reference_enriched_features_v6_fdia_canonical_hc';

CASE_SUFFIX = ['_' CASE_TAG];
MODE_SUFFIX = [CASE_SUFFIX '_chen2022eq' DATASET_VARIANT_TAG];

FN_SPLIT   = ['windows_split' MODE_SUFFIX '.csv'];
FN_LABELS  = ['windows_labels' MODE_SUFFIX '.csv'];
FN_CYBER   = ['windows_cyberlabels' MODE_SUFFIX '.csv'];
FN_NODES   = ['windows_nodes' MODE_SUFFIX '.csv'];
FN_BRANCH  = ['windows_branches' MODE_SUFFIX '.csv'];
FN_GENS    = ['windows_gens' MODE_SUFFIX '.csv'];
FN_META    = ['runs_metadata' MODE_SUFFIX '.csv'];
FN_LINE_ELIGIBILITY = ['line_eligibility' MODE_SUFFIX '.csv'];
FN_LINE_COVERAGE    = ['line_coverage_summary' MODE_SUFFIX '.csv'];
FN_REFERENCE_AUDIT  = ['reference_compliance' MODE_SUFFIX '.csv'];

FN_RAW_NODES  = ['raw_nodes' MODE_SUFFIX '.csv'];
FN_RAW_BRANCH = ['raw_branches' MODE_SUFFIX '.csv'];
FN_RAW_GENS   = ['raw_gens' MODE_SUFFIX '.csv'];
FN_RAW_LABELS = ['raw_labels' MODE_SUFFIX '.csv'];

FN_RAW_TRUTH_NODES  = ['raw_truth_nodes_target_only' MODE_SUFFIX '.csv'];
FN_RAW_TRUTH_BRANCH = ['raw_truth_branches_target_only' MODE_SUFFIX '.csv'];

BASE_SEED   = 123;
PLAN_FILE   = ['run_plan' MODE_SUFFIX '.mat'];

RESTORE_LABELS_ONLY = false;
EXPORT_RAW = true;
EXPORT_WINDOWS = false;

if EXPORT_WINDOWS
    error(['EXPORT_WINDOWS is deprecated in v6. Use EXPORT_RAW=true and build windows in Python ', ...
           'so Theta_est_WLS_preTopo and Pflow_est_WLS_preTopo are preserved.']);
end

MAX_RETRY_PER_RUN = 80;
TLO_VALID_MAX_TRY = 120;

REFERENCE_EQ_TOL = 1e-10;
COVERAGE_ASSERT_ENABLE = true;

NOISE.bus_sigma_rng  = [0.003, 0.012];
NOISE.flow_sigma_rng = [0.004, 0.018];
NOISE.rho_rng        = [0.00, 0.70];
NOISE.bias_std_rng   = [0.00, 0.002];

PMU.ratio_rng       = [0.20, 0.40];
PMU.theta_sigma_rng = [0.0005, 0.002];
PMU.bias_std_rng    = [0.0, 0.0002];

PMU.placement_mode = 'greedy_outage_separation';
PMU.target_ratio = 0.40;
PMU.endpoint_coverage_weight = 0.10;
PMU.mean_separation_weight = 0.02;
PMU_PLACEMENT_VERSION = 'greedy_single_line_dc_signature_v1';

COUNTERFACTUAL.enable = true;
COUNTERFACTUAL.share_event_schedule = true;
COUNTERFACTUAL.share_measurement_randomness = true;

ENRICH.export_truth_targets = true;
ENRICH.attack_value_tolerance = 1e-12;
ENRICH.compute_candidate_topology = true;
ENRICH.candidate_score_stride = 5;
if SMOKE_TEST
    ENRICH.candidate_score_stride = 20;
end
ENRICH.candidate_min_measurements = max(3, round(0.2*14));
ENRICH.truth_files_are_inputs = false;

assert(~ENRICH.truth_files_are_inputs, ...
    'TARGET-ONLY truth files must never be configured as inference inputs.');

LOADPROFILE.busvar_sigma_rng = [0.03, 0.08];
LOADPROFILE.busvar_rho_rng   = [0.50, 0.90];

SECOND_LINE_SAMPLING = 'uniform_without_replacement';

ATTACK.fdia_state_support_ratio_rng = [0.10, 0.40];
ATTACK.fd_scale_rng                  = [0.005, 0.05];
ATTACK.fdia_zero_tol                 = 1e-10;
ATTACK.fdia_reference_tol            = 1e-10;
ATTACK.fdia_max_generation_tries     = 100;

ATTACK.access_ratio_rng = [0.10, 0.40];
ATTACK.alpha_rng        = [0.30, 0.90];

WLS.lambda        = 1e-8;
WLS.rtu_w_scale   = 1.0;
WLS.pmu_w_scale   = 1.0;

FAULTS.enable = true;

FAULTS.RTU.p_outlier = 0.004;
FAULTS.RTU.outlier_k = [5, 12];
FAULTS.RTU.p_missing = 0.002;
FAULTS.RTU.p_stuck   = 0.001;
FAULTS.RTU.stuck_len_rng = [3, 12];

FAULTS.PMU.p_outlier = 0.001;
FAULTS.PMU.outlier_k = [3, 8];
FAULTS.PMU.p_missing = 0.001;
FAULTS.PMU.p_stuck   = 0.0005;
FAULTS.PMU.stuck_len_rng = [2, 8];

ROBUST.min_rcond_B = 1e-10;
ROBUST.min_rcond_A = 1e-12;

det_cols = arrayfun(@(k) sprintf('DetLabel_%d', k), 1:NUM_CLASSES, 'UniformOutput', false);

define_constants;
assert(exist('loadcase','file') == 2, ...
    'MATPOWER is not on the MATLAB path. Add MATPOWER first, then rerun.');
assert(exist(CASE_FILE,'file') == 2, ...
    'MATPOWER case file %s.m was not found on the MATLAB path.', CASE_FILE);

mpc0 = ext2int(loadcase(CASE_FILE));

[BBUS, BF, ~, ~] = makeBdc(mpc0.baseMVA, mpc0.bus, mpc0.branch);
N  = size(mpc0.bus,1);
L  = size(mpc0.branch,1);

assert(N == 14, ...
    'Expected IEEE-14 (14 buses), but %s contains %d buses.', CASE_FILE, N);

slack  = find(mpc0.bus(:, BUS_TYPE) == REF);
keep_b = setdiff((1:N)', slack);

H_bus  = BBUS(keep_b, :);
H_flow = BF;
H      = [H_bus; H_flow];
M_MEAS = size(H,1);
nb1    = numel(keep_b);

loc_cols = arrayfun(@(k) sprintf('LocLabel_%d', k), 1:L, 'UniformOutput', false);

cyber_bus_cols    = arrayfun(@(k) sprintf('CyberBusLabel_%d', k), 1:N, 'UniformOutput', false);
cyber_branch_cols = arrayfun(@(k) sprintf('CyberBranchLabel_%d', k), 1:L, 'UniformOutput', false);

[ELIGIBLE_TLO_LINES, INELIGIBLE_TLO_LINES, TlineEligibility] = ...
    determine_eligible_single_lines(mpc0, slack, keep_b, BR_STATUS, F_BUS, T_BUS, ROBUST.min_rcond_B);

assert(~isempty(ELIGIBLE_TLO_LINES), 'No structurally eligible line outages were found.');
writetable(TlineEligibility, FN_LINE_ELIGIBILITY);

plan_ok = false;
if isfile(PLAN_FILE)
    S = load(PLAN_FILE);
    plan_ok = isfield(S,'scenario_pool') && isfield(S,'split_pool') && ...
              isfield(S,'BASE_STATE_PLAN') && numel(S.BASE_STATE_PLAN) == NUM_RUNS_TARGET && ...
              isfield(S,'TLO_TIME_PLAN') && isfield(S,'FDIA_TIME_PLAN') && ...
              isfield(S,'NUM_RUNS_TARGET') && (S.NUM_RUNS_TARGET == NUM_RUNS_TARGET) && ...
              isfield(S,'NUM_BASE_STATES_SAVED') && ...
              (S.NUM_BASE_STATES_SAVED == NUM_BASE_STATES) && ...
              isfield(S,'RUNS_PER_CLASS_SAVED') && ...
              (S.RUNS_PER_CLASS_SAVED == RUNS_PER_CLASS) && ...
              isfield(S,'PMU_BUSES') && isfield(S,'pmu_ratio') && isfield(S,'BASE_SEED') && ...
              isfield(S,'CASE_FILE_SAVED') && strcmp(string(S.CASE_FILE_SAVED), string(CASE_FILE)) && ...
              isfield(S,'N_SAVED') && (S.N_SAVED == N) && ...
              isfield(S,'L_SAVED') && (S.L_SAVED == L) && ...
              isfield(S,'TLO_ANCHOR_PLAN') && numel(S.TLO_ANCHOR_PLAN) == NUM_RUNS_TARGET && ...
              isfield(S,'ELIGIBLE_TLO_LINES_SAVED') && ...
              isequal(sort(S.ELIGIBLE_TLO_LINES_SAVED(:)'), sort(ELIGIBLE_TLO_LINES(:)')) && ...
              isfield(S,'OUTAGE_SAMPLING_VERSION_SAVED') && ...
              strcmp(string(S.OUTAGE_SAMPLING_VERSION_SAVED), string(OUTAGE_SAMPLING_VERSION)) && ...
              isfield(S,'COUNTERFACTUAL_VERSION_SAVED') && ...
              strcmp(string(S.COUNTERFACTUAL_VERSION_SAVED), string(COUNTERFACTUAL_VERSION)) && ...
              isfield(S,'PMU_PLACEMENT_VERSION_SAVED') && ...
              strcmp(string(S.PMU_PLACEMENT_VERSION_SAVED), string(PMU_PLACEMENT_VERSION)) && ...
              isfield(S,'PMU_PLACEMENT_MODE_SAVED') && ...
              strcmp(string(S.PMU_PLACEMENT_MODE_SAVED), string(PMU.placement_mode)) && ...
              isfield(S,'CCPA_EQUATION_MODE_SAVED') && ...
              strcmp(string(S.CCPA_EQUATION_MODE_SAVED), string(CCPA_EQUATION_MODE)) && ...
              isfield(S,'FDIA_CONSTRUCTION_MODE_SAVED') && ...
              strcmp(string(S.FDIA_CONSTRUCTION_MODE_SAVED), string(FDIA_CONSTRUCTION_MODE)) && ...
              isfield(S,'FDIA_VERSION_SAVED') && ...
              strcmp(string(S.FDIA_VERSION_SAVED), string(FDIA_VERSION)) && ...
              isfield(S,'OUTAGE_SAMPLING_MODE_SAVED') && ...
              strcmp(string(S.OUTAGE_SAMPLING_MODE_SAVED), string(OUTAGE_SAMPLING_MODE)) && ...
              isfield(S,'MAX_OUTAGED_LINES_PRIMARY_SAVED') && ...
              S.MAX_OUTAGED_LINES_PRIMARY_SAVED == MAX_OUTAGED_LINES_PRIMARY && ...
              all(S.PMU_BUSES(:) >= 1) && all(S.PMU_BUSES(:) <= N);
    if plan_ok
        scenario_pool   = S.scenario_pool;
        split_pool      = S.split_pool;
        BASE_STATE_PLAN = S.BASE_STATE_PLAN;
        TLO_TIME_PLAN   = S.TLO_TIME_PLAN;
        FDIA_TIME_PLAN  = S.FDIA_TIME_PLAN;
        PMU_BUSES       = S.PMU_BUSES;
        pmu_ratio       = S.pmu_ratio;
        BASE_SEED       = S.BASE_SEED;
        TLO_ANCHOR_PLAN = S.TLO_ANCHOR_PLAN;
    else
        warning('%s is invalid or belongs to an older schema; rebuilding the v11 plan.', PLAN_FILE);
        try, delete(PLAN_FILE); end
        plan_ok = false;
    end
end

if ~plan_ok
    rng(BASE_SEED, 'twister');

    [scenario_pool, split_pool, BASE_STATE_PLAN, TLO_ANCHOR_PLAN, ...
        TLO_TIME_PLAN, FDIA_TIME_PLAN] = build_counterfactual_bundle_plan( ...
        CLASS_NAMES, NUM_BASE_STATES, T_TOTAL, ELIGIBLE_TLO_LINES, BASE_SEED + 77123);

    pmu_ratio = PMU.target_ratio;
    if strcmpi(PMU.placement_mode, 'greedy_outage_separation')
        PMU_BUSES = choose_pmu_buses_outage_separation( ...
            mpc0, ELIGIBLE_TLO_LINES, slack, pmu_ratio, ...
            BR_STATUS, F_BUS, T_BUS, VA, PMU.endpoint_coverage_weight, ...
            PMU.mean_separation_weight);
    elseif strcmpi(PMU.placement_mode, 'random_ratio')
        PMU_BUSES = choose_pmu_buses(N, slack, pmu_ratio);
    else
        error('Unknown PMU.placement_mode: %s', PMU.placement_mode);
    end

    CASE_FILE_SAVED = CASE_FILE;
    N_SAVED = N;
    L_SAVED = L;
    ELIGIBLE_TLO_LINES_SAVED = ELIGIBLE_TLO_LINES;
    OUTAGE_SAMPLING_VERSION_SAVED = OUTAGE_SAMPLING_VERSION;
    COUNTERFACTUAL_VERSION_SAVED = COUNTERFACTUAL_VERSION;
    PMU_PLACEMENT_VERSION_SAVED = PMU_PLACEMENT_VERSION;
    PMU_PLACEMENT_MODE_SAVED = PMU.placement_mode;
    CCPA_EQUATION_MODE_SAVED = CCPA_EQUATION_MODE;
    FDIA_CONSTRUCTION_MODE_SAVED = FDIA_CONSTRUCTION_MODE;
    FDIA_VERSION_SAVED = FDIA_VERSION;
    OUTAGE_SAMPLING_MODE_SAVED = OUTAGE_SAMPLING_MODE;
    MAX_OUTAGED_LINES_PRIMARY_SAVED = MAX_OUTAGED_LINES_PRIMARY;
    NUM_BASE_STATES_SAVED = NUM_BASE_STATES;
    RUNS_PER_CLASS_SAVED = RUNS_PER_CLASS;

    save(PLAN_FILE, 'scenario_pool', 'split_pool', 'BASE_STATE_PLAN', ...
                    'TLO_TIME_PLAN', 'FDIA_TIME_PLAN', ...
                    'PMU_BUSES', 'pmu_ratio', 'TLO_ANCHOR_PLAN', ...
                    'ELIGIBLE_TLO_LINES_SAVED', 'OUTAGE_SAMPLING_VERSION_SAVED', ...
                    'COUNTERFACTUAL_VERSION_SAVED', 'PMU_PLACEMENT_VERSION_SAVED', ...
                    'PMU_PLACEMENT_MODE_SAVED', 'CCPA_EQUATION_MODE_SAVED', ...
                    'FDIA_CONSTRUCTION_MODE_SAVED', 'FDIA_VERSION_SAVED', ...
                    'OUTAGE_SAMPLING_MODE_SAVED', 'MAX_OUTAGED_LINES_PRIMARY_SAVED', ...
                    'BASE_SEED', 'NUM_RUNS_TARGET', ...
                    'NUM_BASE_STATES_SAVED', 'RUNS_PER_CLASS_SAVED', ...
                    'CASE_FILE_SAVED', 'N_SAVED', 'L_SAVED');
end

assert(numel(scenario_pool) == NUM_RUNS_TARGET, ...
    'Scenario plan length %d does not match NUM_RUNS_TARGET=%d.', ...
    numel(scenario_pool), NUM_RUNS_TARGET);
assert(numel(unique(BASE_STATE_PLAN)) == NUM_BASE_STATES, ...
    'The plan contains %d BaseState_ID values; expected %d.', ...
    numel(unique(BASE_STATE_PLAN)), NUM_BASE_STATES);
assert(all(histcounts(BASE_STATE_PLAN, 0.5:1:(NUM_BASE_STATES+0.5)) == NUM_CLASSES), ...
    'Every BaseState_ID must contain exactly one run from each class.');

validate_anchor_plan(scenario_pool, split_pool, TLO_ANCHOR_PLAN, ELIGIBLE_TLO_LINES);
validate_counterfactual_bundle_plan( ...
    scenario_pool, split_pool, BASE_STATE_PLAN, TLO_ANCHOR_PLAN, ...
    TLO_TIME_PLAN, FDIA_TIME_PLAN, CLASS_NAMES);

CANDIDATE_MODELS = precompute_candidate_topology_models( ...
    mpc0, keep_b, slack, BR_STATUS, F_BUS, T_BUS, ROBUST.min_rcond_B);

Tconfig = table(string(CASE_FILE), string(CCPA_EQUATION_MODE), string(CCPA_MASKING_MODE), ...
                string(FDIA_CONSTRUCTION_MODE), string(FDIA_VERSION), string(FDIA_REFERENCE_TITLE), ...
                string(OUTAGE_SAMPLING_MODE), string(SECOND_LINE_SAMPLING), string(MODE_SUFFIX), ...
                string(DATASET_VARIANT_TAG), string(OUTAGE_SAMPLING_VERSION), MAX_OUTAGED_LINES_PRIMARY, ...
                N, L, size(mpc0.gen,1), ...
                NUM_RUNS_TARGET, RUNS_PER_CLASS, T_TOTAL, T_WIN, STRIDE, ...
                MAX_RETRY_PER_RUN, TLO_VALID_MAX_TRY, ...
                ATTACK.fdia_state_support_ratio_rng(1), ATTACK.fdia_state_support_ratio_rng(2), ...
                ATTACK.fd_scale_rng(1), ATTACK.fd_scale_rng(2), ...
                ATTACK.fdia_zero_tol, ATTACK.fdia_reference_tol, ATTACK.fdia_max_generation_tries, ...
                ATTACK.access_ratio_rng(1), ATTACK.access_ratio_rng(2), ...
                ATTACK.alpha_rng(1), ATTACK.alpha_rng(2), ...
                pmu_ratio, string(mat2str(PMU_BUSES(:)')), ...
                string(mat2str(ELIGIBLE_TLO_LINES)), string(mat2str(INELIGIBLE_TLO_LINES)), ...
                REFERENCE_EQ_TOL, ...
                string(FN_RAW_NODES), string(FN_RAW_BRANCH), string(FN_RAW_LABELS), string(FN_META), ...
    'VariableNames', {'CaseFile','CCPAEquationMode','CCPAMaskingMode', ...
                      'FDIAConstructionMode','FDIAVersion','FDIAReferenceTitle', ...
                      'OutageSamplingMode','SecondLineSampling','ModeSuffix', ...
                      'DatasetVariantTag','OutageSamplingVersion','MaxOutagedLinesPrimary', ...
                      'NumBuses','NumBranches','NumGenerators', ...
                      'NumRunsTarget','RunsPerClass','TTotal','TWindow','Stride', ...
                      'MaxRetryPerRun','TLOValidMaxTry', ...
                      'FDIAStateSupportRatioMin','FDIAStateSupportRatioMax','FDScaleMin','FDScaleMax', ...
                      'FDIAZeroTolerance','FDIAReferenceTolerance','FDIAMaxGenerationTries', ...
                      'ExtensionAccessRatioMin','ExtensionAccessRatioMax', ...
                      'AlphaMin','AlphaMax','PMURatio','PMUBuses', ...
                      'EligibleTLOLines','IneligibleTLOLines','ReferenceEquationTolerance', ...
                      'RawNodesFile','RawBranchesFile','RawLabelsFile','MetadataFile'});
writetable(Tconfig, ['dataset_config' MODE_SUFFIX '.csv']);

TenrichConfig = table( ...
    string(FEATURE_SCHEMA_VERSION), string(COUNTERFACTUAL_VERSION), COUNTERFACTUAL.enable, ...
    RUNS_PER_CLASS, NUM_BASE_STATES, ...
    string(PMU.placement_mode), string(PMU_PLACEMENT_VERSION), PMU.target_ratio, ...
    ENRICH.compute_candidate_topology, ENRICH.candidate_score_stride, ...
    string('theta_slack_equals_zero'), ...
    ENRICH.export_truth_targets, string(FN_RAW_TRUTH_NODES), string(FN_RAW_TRUTH_BRANCH), ...
    'VariableNames', {'FeatureSchemaVersion','CounterfactualVersion','CounterfactualEnabled', ...
    'RunsPerClass','NumBaseStates','PMUPlacementMode','PMUPlacementVersion','PMUTargetRatio', ...
    'CandidateTopologyEnabled','CandidateScoreStride','RTUOnlyWLSReference', ...
    'TruthTargetsExported','TruthNodesFile','TruthBranchesFile'});
writetable(TenrichConfig, ['enrichment_config' MODE_SUFFIX '.csv']);

AuditItem = [ ...
    "DC power-flow attack model"; ...
    "Standalone FDIA equation"; ...
    "Standalone FDIA sampling"; ...
    "Partial CCPA equation"; ...
    "Full CCPA equation"; ...
    "Paper-faithful cyber access"; ...
    "No-MTD baseline"; ...
    "RTU measurement layout"; ...
    "Protected PMU channels"; ...
    "Noise/fault/load process"; ...
    "Temporal multi-task labels"; ...
    "Balanced outage-anchor plan"; ...
    "Uniform second-line sampling"; ...
    "Maximum outage cardinality"; ...
    "Counterfactual bundle grouping"; ...
    "Protected PMU placement optimization"; ...
    "Candidate-topology feature bank"; ...
    "Clean-state/attack target export" ];
AuditStatus = [ ...
    "MATCH"; ...
    "EXACT_CANONICAL_HC"; ...
    "THESIS_EXTENSION"; ...
    "EXACT_EQ4"; ...
    "EXACT_EQ6"; ...
    "MATCH_UNRESTRICTED"; ...
    "MATCH_APPROACH1"; ...
    "THESIS_EXTENSION"; ...
    "THESIS_EXTENSION"; ...
    "THESIS_EXTENSION"; ...
    "THESIS_EXTENSION"; ...
    "CONTROLLED_EXPERIMENT_DESIGN"; ...
    "CONTROLLED_EXPERIMENT_DESIGN"; ...
    "REFERENCE_ALIGNED_MAX2"; ...
    "CONTROLLED_EXPERIMENT_DESIGN"; ...
    "THESIS_EXTENSION"; ...
    "THESIS_EXTENSION"; ...
    "TARGET_ONLY_THESIS_EXTENSION" ];
AuditNote = [ ...
    "Uses DC rundcpf and a linear z=H*theta model."; ...
    "Uses a=H*c exactly as formulated in 'False Data Injection Attacks against State Estimation in Electric Power Grids'; no post-construction measurement mask is applied."; ...
    "Sparse non-slack state support, Gaussian coefficients, and magnitude ranges are thesis-specific sampling choices."; ...
    "ac=-DeltaH*theta_p; runtime identity assertion enabled."; ...
    "ac=-(H*Delta_theta+DeltaH*theta_p)=z-z_p; runtime identity assertion enabled."; ...
    "All RTU attack channels are writable in paper_faithful Partial/Full CCPA."; ...
    "No moving-target reactance perturbation is applied."; ...
    "Uses non-slack injections plus forward flows; not the paper's exact 54-channel vector."; ...
    "Protected PMUs are an intentional thesis contribution, not part of the reference baseline."; ...
    "Heteroskedastic AR(1) noise, faults, and correlated loads extend the paper simulation."; ...
    "Five-class temporal detection plus physical/cyber localization extends the paper task."; ...
    "Balances learnable line labels without modifying any attack equation."; ...
    "A second eligible line is sampled uniformly; no unreferenced 0.70 adjacency probability is used."; ...
    "At most two lines are outaged in the primary dataset."; ...
    "All five classes sharing a BaseState_ID remain in one split; attack equations are unchanged."; ...
    "Greedy placement uses only the DC network and simulated single-line signatures; PMUs remain protected."; ...
    "Every candidate line is scored from observed RTU/PMU data under a fixed predeclared topology bank."; ...
    "Ground-truth clean states and cyber vectors are written to separate target-only files, never model inputs." ];
TreferenceAudit = table(AuditItem, AuditStatus, AuditNote);
writetable(TreferenceAudit, FN_REFERENCE_AUDIT);

start_r = 1;

if EXPORT_RAW && ~EXPORT_WINDOWS && isfile(FN_META)
    try
        tm = readtable(FN_META);
        if ~isempty(tm), start_r = max(tm.Run_ID) + 1; end
    catch
        start_r = 1;
    end
elseif isfile(FN_SPLIT)
    try
        ws = readtable(FN_SPLIT);
        if ~isempty(ws), start_r = max(ws.Run_ID) + 1; end
    catch
        start_r = 1;
    end
end

NUM_RUNS = NUM_RUNS_TARGET;

if isfile(FN_SPLIT)
    try
        ws = readtable(FN_SPLIT);
        WIN_COUNTER = max(ws.Window_ID);
    catch
        WIN_COUNTER = 0;
    end
else
    WIN_COUNTER = 0;
end

if RESTORE_LABELS_ONLY
    if isfile(FN_SPLIT),  delete(FN_SPLIT);  end
    if isfile(FN_LABELS), delete(FN_LABELS); end
    if isfile(FN_CYBER),  delete(FN_CYBER);  end
    WIN_COUNTER = 0;
end

for r = start_r:NUM_RUNS
    scenario  = scenario_pool(r);
    split_tag = split_pool(r);
    base_state_id = BASE_STATE_PLAN(r);
    planned_t_tlo = TLO_TIME_PLAN(r);
    planned_t_fdia = FDIA_TIME_PLAN(r);
    anchor_line = TLO_ANCHOR_PLAN(r);

    [load_scale_fixed, bus_idio_fixed, busvar_sigma_fixed, busvar_rho_fixed] = ...
        make_counterfactual_operating_profile( ...
        N, T_TOTAL, LOADPROFILE, BASE_SEED + 2000000 + base_state_id);

    run_success = false;
    retries_used = 0;
    last_fail_reason = "not started";

    for att = 1:MAX_RETRY_PER_RUN
        retries_used = att - 1;

        rng(BASE_SEED + 100000*base_state_id + att, 'twister');

        if att <= 50
            k_min = 1; k_max = MAX_OUTAGED_LINES_PRIMARY;
            min_rcond_B_eff = ROBUST.min_rcond_B;
        else
            k_min = 1; k_max = 1;
            min_rcond_B_eff = min(ROBUST.min_rcond_B, 1e-12);
        end

        load_scale = load_scale_fixed;
        bus_idio = bus_idio_fixed;
        busvar_sigma = busvar_sigma_fixed;
        busvar_rho = busvar_rho_fixed;

        run = simulate_run_with_profile(mpc0, T_TOTAL, load_scale, bus_idio, BBUS, BF, VA, PD);

        run.H      = H;
        run.keep_b = keep_b;
        run.slack  = slack;

        run.events.TLO_times  = [];
        run.events.FDIA_times = [];
        run.events.CCPA_type  = "";

        run.PMU_BUSES = PMU_BUSES;

        run.meta.mask         = zeros(M_MEAS,1);
        run.meta.access_ratio = NaN;
        run.meta.alpha        = NaN;
        run.meta.fdia_construction_mode = "";
        run.meta.fdia_state_support_size = NaN;
        run.meta.fdia_state_support_ratio = NaN;
        run.meta.fdia_measurement_support_size = NaN;
        run.meta.fdia_measurement_support_ratio = NaN;
        run.meta.fdia_c_l2 = NaN;
        run.meta.fdia_hc_l2 = NaN;
        run.meta.fdia_attack_l2 = NaN;
        run.meta.fdia_reference_error_inf = NaN;
        run.meta.min_rcond_B_eff = min_rcond_B_eff;
        run.meta.outage_sampling_mode = string(OUTAGE_SAMPLING_MODE);
        run.meta.k_min_eff = k_min;
        run.meta.k_max_eff = k_max;
        run.meta.tlo_anchor_line = anchor_line;
        run.meta.base_state_id = base_state_id;
        run.meta.counterfactual_version = string(COUNTERFACTUAL_VERSION);
        run.meta.busvar_sigma = busvar_sigma;
        run.meta.busvar_rho = busvar_rho;

        run.cyber.bus_mask    = zeros(N,1);
        run.cyber.branch_mask = zeros(L,1);

        ok_attack = true;

        switch char(scenario)
            case 'NORMAL'

            case 'FDIA'
                t_fdia = planned_t_fdia;

                [c, fdia_info, ok_fdia] = generate_canonical_fdia_c( ...
                    N, slack, ATTACK.fdia_state_support_ratio_rng, ...
                    ATTACK.fd_scale_rng, ATTACK.fdia_zero_tol, ...
                    ATTACK.fdia_max_generation_tries);

                if ~ok_fdia
                    ok_attack = false;
                    last_fail_reason = 'Failed to generate a nonzero canonical FDIA c-vector.';
                else

                    a = H * c;

                    reference_error = norm(a - H*c, inf);
                    reference_scale = max(1.0, norm(a, inf));

                    if norm(a, 2) <= ATTACK.fdia_zero_tol
                        ok_attack = false;
                        last_fail_reason = 'Canonical FDIA attack vector H*c is zero or near zero.';
                    elseif reference_error > ATTACK.fdia_reference_tol * reference_scale
                        ok_attack = false;
                        last_fail_reason = sprintf( ...
                            'Canonical FDIA a=H*c identity failed: abs_err=%.3e.', ...
                            reference_error);
                    else
                        attack_support_mask = double( ...
                            abs(a) > ENRICH.attack_value_tolerance);

                        run = inject_canonical_FDIA(run, t_fdia, c, a, fdia_info);

                        run.meta.mask = attack_support_mask;
                        run.meta.access_ratio = nnz(attack_support_mask) / M_MEAS;
                        run.meta.fdia_construction_mode = string(FDIA_CONSTRUCTION_MODE);
                        run.meta.fdia_state_support_size = fdia_info.support_size;
                        run.meta.fdia_state_support_ratio = fdia_info.support_ratio;
                        run.meta.fdia_measurement_support_size = nnz(attack_support_mask);
                        run.meta.fdia_measurement_support_ratio = nnz(attack_support_mask) / M_MEAS;
                        run.meta.fdia_c_l2 = norm(c, 2);
                        run.meta.fdia_hc_l2 = norm(H*c, 2);
                        run.meta.fdia_attack_l2 = norm(a, 2);
                        run.meta.fdia_reference_error_inf = reference_error;

                        [busm, brm] = map_meas_mask_to_graph( ...
                            attack_support_mask, keep_b, N, L);
                        run.cyber.bus_mask    = busm;
                        run.cyber.branch_mask = brm;
                    end
                end

            case 'TLO'
                run.TLO.t0 = planned_t_tlo;

                [ok, lines_set, Hp, ap0] = sample_tlo_valid( ...
                    mpc0, run, H, PD, VA, BR_STATUS, F_BUS, T_BUS, ...
                    TLO_VALID_MAX_TRY, k_min, k_max, min_rcond_B_eff, ...
                    anchor_line, ELIGIBLE_TLO_LINES);

                if ~ok
                    ok_attack = false;
                else
                    run.TLO.lines = lines_set;
                    run.TLO.anchor_line = anchor_line;
                    assert(any(lines_set == anchor_line), 'Accepted outage set lost its planned anchor line.');
                    run.Hp        = Hp;
                    run.TLO.ap0   = ap0;

                    run.events.TLO_times(end+1) = run.TLO.t0;
                    for t = run.TLO.t0:run.T_total
                        run.edge_outage(t, lines_set) = true;
                    end
                end

            case 'CCPA_FULL'
                t_tlo = planned_t_tlo;
                t_fdia = planned_t_fdia;

                run.TLO.t0 = t_tlo;

                [ok, lines_set, Hp, ap0] = sample_tlo_valid( ...
                    mpc0, run, H, PD, VA, BR_STATUS, F_BUS, T_BUS, ...
                    TLO_VALID_MAX_TRY, k_min, k_max, min_rcond_B_eff, ...
                    anchor_line, ELIGIBLE_TLO_LINES);

                if ~ok
                    ok_attack = false;
                else
                    run.TLO.lines = lines_set;
                    run.TLO.anchor_line = anchor_line;
                    assert(any(lines_set == anchor_line), 'Accepted outage set lost its planned anchor line.');
                    run.Hp        = Hp;
                    run.TLO.ap0   = ap0;

                    run.events.TLO_times(end+1) = t_tlo;
                    for t = t_tlo:run.T_total
                        run.edge_outage(t, lines_set) = true;
                    end

                    if strcmp(char(CCPA_MASKING_MODE), 'paper_faithful')

                        access_ratio = 1.0;
                        mask = true(M_MEAS, 1);
                    else
                        access_ratio = rand_between(ATTACK.access_ratio_rng(1), ATTACK.access_ratio_rng(2));
                        mask = sample_attack_mask(M_MEAS, access_ratio);
                    end

                    run.CCPA.t_FDIA = t_fdia;
                    run.CCPA.alpha  = 1.0;
                    run.CCPA.mask   = mask;
                    run.CCPA.access_ratio = access_ratio;

                    run.events.FDIA_times(end+1) = t_fdia;
                    run.events.CCPA_type = "FULL";

                    run.meta.mask = mask;
                    run.meta.access_ratio = access_ratio;
                    run.meta.alpha = 1.0;

                    [busm, brm] = map_meas_mask_to_graph(mask, keep_b, N, L);
                    run.cyber.bus_mask    = busm;
                    run.cyber.branch_mask = brm;
                end

            case 'CCPA_PARTIAL'
                t_tlo = planned_t_tlo;
                t_fdia = planned_t_fdia;

                run.TLO.t0 = t_tlo;

                [ok, lines_set, Hp, ap0] = sample_tlo_valid( ...
                    mpc0, run, H, PD, VA, BR_STATUS, F_BUS, T_BUS, ...
                    TLO_VALID_MAX_TRY, k_min, k_max, min_rcond_B_eff, ...
                    anchor_line, ELIGIBLE_TLO_LINES);

                if ~ok
                    ok_attack = false;
                else
                    run.TLO.lines = lines_set;
                    run.TLO.anchor_line = anchor_line;
                    assert(any(lines_set == anchor_line), 'Accepted outage set lost its planned anchor line.');
                    run.Hp        = Hp;
                    run.TLO.ap0   = ap0;

                    run.events.TLO_times(end+1) = t_tlo;
                    for t = t_tlo:run.T_total
                        run.edge_outage(t, lines_set) = true;
                    end

                    if strcmp(char(CCPA_MASKING_MODE), 'paper_faithful')

                        alpha = NaN;
                        access_ratio = 1.0;
                        mask = true(M_MEAS, 1);
                    else
                        alpha = rand_between(ATTACK.alpha_rng(1), ATTACK.alpha_rng(2));
                        access_ratio = rand_between(ATTACK.access_ratio_rng(1), ATTACK.access_ratio_rng(2));
                        mask = sample_attack_mask(M_MEAS, access_ratio);
                    end

                    run.CCPA.t_FDIA = t_fdia;
                    run.CCPA.alpha  = alpha;
                    run.CCPA.mask   = mask;
                    run.CCPA.access_ratio = access_ratio;

                    run.events.FDIA_times(end+1) = t_fdia;
                    run.events.CCPA_type = "PARTIAL";

                    run.meta.mask = mask;
                    run.meta.access_ratio = access_ratio;
                    run.meta.alpha = alpha;

                    [busm, brm] = map_meas_mask_to_graph(mask, keep_b, N, L);
                    run.cyber.bus_mask    = busm;
                    run.cyber.branch_mask = brm;
                end
        end

        if ~ok_attack
            if ismember(string(scenario), ["TLO","CCPA_FULL","CCPA_PARTIAL"])
                last_fail_reason = sprintf(['No valid TLO/topology candidate preserving anchor=%g ', ...
                    '(att=%d, k=[%d,%d], sampling=uniform, min_rcond=%.3g).'], ...
                    anchor_line, att, k_min, k_max, min_rcond_B_eff);
            elseif strcmp(string(last_fail_reason), "not started")
                last_fail_reason = sprintf('Attack generation failed at attempt %d.', att);
            end
            continue;
        end

        if ismember(string(scenario), ["TLO","CCPA_FULL","CCPA_PARTIAL"])
            assert(isfield(run,'TLO') && numel(run.TLO.lines) >= 1 && ...
                   numel(run.TLO.lines) <= MAX_OUTAGED_LINES_PRIMARY, ...
                'Accepted outage cardinality violates the final primary max-two policy.');
            assert(any(run.TLO.lines == anchor_line), ...
                'Accepted outage set does not contain its balanced planned anchor.');
        end

        if COUNTERFACTUAL.share_measurement_randomness
            rng(BASE_SEED + 5000000 + 1000*base_state_id + att, 'twister');
        end
        run.noise = random_noise_models(NOISE, PMU, M_MEAS, nb1, L, N, PMU_BUSES);

        try
            run = realize_measurements_with_attacks_RTU_PMU_protected_WLSpre_faults( ...
                run, mpc0, H, run.noise, BBUS, BF, PD, VA, BR_STATUS, ...
                WLS, F_BUS, T_BUS, FAULTS, ROBUST, CCPA_MASKING_MODE, REFERENCE_EQ_TOL, ...
                CANDIDATE_MODELS, ENRICH);
        catch ME
            last_fail_reason = sprintf('Measurement realization failed at att=%d: %s', att, ME.message);
            continue;
        end

        finite_rtu_state_steps = cellfun(@(x) any(isfinite(x)), run.theta_hat_wls_pre_rtu);
        assert(any(finite_rtu_state_steps), ...
            'RTU-only WLS produced no finite state estimate; check slack referencing.');

        if ENRICH.compute_candidate_topology
            assert(any(isfinite(run.candidate_rtu_rms(:))), ...
                'Candidate RTU-only topology scores are all NaN.');
        end

        run.difficulty = summarize_run_physics_difficulty(run, ENRICH.attack_value_tolerance);
        run_success = true;
        break;
    end

    if ~run_success
        error('Run %d failed after %d retries (scenario=%s). Last failure: %s', ...
              r, MAX_RETRY_PER_RUN, string(scenario), char(last_fail_reason));
    end

    if EXPORT_RAW
        export_raw_run(run, r, split_tag, string(scenario), CLASS_NAMES, L, N, ...
                       det_cols, loc_cols, cyber_bus_cols, cyber_branch_cols, ...
                       mpc0.branch(:, F_BUS), mpc0.branch(:, T_BUS), BF, ...
                       FN_RAW_NODES, FN_RAW_BRANCH, FN_RAW_GENS, FN_RAW_LABELS, ...
                       FN_RAW_TRUTH_NODES, FN_RAW_TRUTH_BRANCH, ENRICH);
    end

    t_fdia_meta = NaN;
    t_tlo_meta = NaN;
    alpha_meta = NaN;
    acc_meta = NaN;

    lines_str = "";
    anchor_meta = NaN;
    num_lines_meta = 0;

    fdia_mode_meta = "";
    fdia_state_support_size_meta = NaN;
    fdia_state_support_ratio_meta = NaN;
    fdia_measurement_support_size_meta = NaN;
    fdia_measurement_support_ratio_meta = NaN;
    fdia_c_l2_meta = NaN;
    fdia_hc_l2_meta = NaN;
    fdia_attack_l2_meta = NaN;
    fdia_reference_error_inf_meta = NaN;

    if isfield(run,'FDIA') && ~isempty(run.FDIA)
        t_fdia_meta = run.FDIA.t0;
        fdia_mode_meta = string(run.meta.fdia_construction_mode);
        fdia_state_support_size_meta = run.meta.fdia_state_support_size;
        fdia_state_support_ratio_meta = run.meta.fdia_state_support_ratio;
        fdia_measurement_support_size_meta = run.meta.fdia_measurement_support_size;
        fdia_measurement_support_ratio_meta = run.meta.fdia_measurement_support_ratio;
        fdia_c_l2_meta = run.meta.fdia_c_l2;
        fdia_hc_l2_meta = run.meta.fdia_hc_l2;
        fdia_attack_l2_meta = run.meta.fdia_attack_l2;
        fdia_reference_error_inf_meta = run.meta.fdia_reference_error_inf;
    end

    if isfield(run,'TLO') && ~isempty(run.TLO)
        t_tlo_meta = run.TLO.t0;
        lines_str = mat2str(run.TLO.lines);
        anchor_meta = run.TLO.anchor_line;
        num_lines_meta = numel(run.TLO.lines);
    end

    if isfield(run,'CCPA') && ~isempty(run.CCPA)
        t_fdia_meta = run.CCPA.t_FDIA;
        alpha_meta = run.CCPA.alpha;
        acc_meta   = run.CCPA.access_ratio;
    elseif isfield(run,'FDIA') && ~isempty(run.FDIA)
        acc_meta = run.meta.access_ratio;
    end

    Tmeta = table(r, base_state_id, split_tag, string(scenario), retries_used, ...
                  run.T_total, ...
                  t_tlo_meta, t_fdia_meta, alpha_meta, acc_meta, string(lines_str), anchor_meta, num_lines_meta, ...
                  fdia_mode_meta, fdia_state_support_size_meta, fdia_state_support_ratio_meta, ...
                  fdia_measurement_support_size_meta, fdia_measurement_support_ratio_meta, ...
                  fdia_c_l2_meta, fdia_hc_l2_meta, fdia_attack_l2_meta, fdia_reference_error_inf_meta, ...
                  run.noise.rtu.bus_sigma, run.noise.rtu.flow_sigma, run.noise.rtu.rho, run.noise.rtu.bias_std, ...
                  run.noise.pmu.theta_sigma, run.noise.pmu.bias_std, ...
                  numel(PMU_BUSES), pmu_ratio, string(mat2str(PMU_BUSES(:)')), ...
                  run.faults_stats.RTU_outlier_rate, run.faults_stats.RTU_missing_rate, run.faults_stats.RTU_stuck_rate, ...
                  run.faults_stats.PMU_outlier_rate, run.faults_stats.PMU_missing_rate, run.faults_stats.PMU_stuck_rate, ...
                  run.meta.busvar_sigma, run.meta.busvar_rho, string(PMU.placement_mode), ...
                  run.difficulty.OutagedLinePreFlowMean, run.difficulty.OutagedLinePreFlowMax, ...
                  run.difficulty.PhysicalEffectL2, run.difficulty.CyberEffectL2, ...
                  run.difficulty.VisiblePostAttackL2, run.difficulty.PMUAngleChangeL2, ...
                  run.difficulty.PostOutageFlowRedistributionL2, run.difficulty.MaskingRatio, ...
                  'VariableNames', {'Run_ID','BaseState_ID','Split','ClassName','RetriesUsed', ...
                                    'NumTimeSteps', ...
                                    'TLO_t0','FDIA_t0','CCPA_alpha','Attack_access_ratio','TLO_lines','TLO_AnchorLine','TLO_NumLines', ...
                                    'FDIA_Construction_Mode','FDIA_State_Support_Size','FDIA_State_Support_Ratio', ...
                                    'FDIA_Measurement_Support_Size','FDIA_Measurement_Support_Ratio', ...
                                    'FDIA_c_L2','FDIA_Hc_L2','FDIA_Attack_L2','FDIA_Reference_Error_Inf', ...
                                    'RTU_bus_sigma','RTU_flow_sigma','RTU_rho','RTU_bias_std', ...
                                    'PMU_theta_sigma','PMU_bias_std', ...
                                    'PMU_count','PMU_ratio','PMU_buses', ...
                                    'RTU_outlier_rate','RTU_missing_rate','RTU_stuck_rate', ...
                                    'PMU_outlier_rate','PMU_missing_rate','PMU_stuck_rate', ...
                                    'BusIdioSigma','BusIdioRho','PMUPlacementMode', ...
                                    'OutagedLinePreFlowMean','OutagedLinePreFlowMax', ...
                                    'PhysicalEffectL2','CyberEffectL2','VisiblePostAttackL2','PMUAngleChangeL2', ...
                                    'PostOutageFlowRedistributionL2','MaskingRatio'});

    append_csv(Tmeta, FN_META);

    if EXPORT_WINDOWS
    [WinList, YdList, YlList, idxList, WinClassList] = windows_all(run, T_WIN, STRIDE, CLASS_NAMES, L);

    NumWindowsRun = numel(WinList);

    classCounts = zeros(numel(CLASS_NAMES),1);
    for ci = 1:numel(CLASS_NAMES)
        classCounts(ci) = nnz(WinClassList == CLASS_NAMES(ci));
    end

    t_fdia_meta = NaN; t_tlo_meta = NaN; alpha_meta = NaN; acc_meta = NaN; lines_str = "";
    anchor_meta = NaN; num_lines_meta = 0;
    if isfield(run,'FDIA') && ~isempty(run.FDIA), t_fdia_meta = run.FDIA.t0; end
    if isfield(run,'TLO')  && ~isempty(run.TLO)
        t_tlo_meta = run.TLO.t0; lines_str = mat2str(run.TLO.lines);
        anchor_meta = run.TLO.anchor_line; num_lines_meta = numel(run.TLO.lines);
    end
    if isfield(run,'CCPA') && ~isempty(run.CCPA)
        alpha_meta = run.CCPA.alpha;
        acc_meta   = run.CCPA.access_ratio;
    elseif isfield(run,'FDIA') && ~isempty(run.FDIA)
        acc_meta = run.meta.access_ratio;
    end

    Tmeta = table(r, split_tag, string(scenario), retries_used, ...
                  NumWindowsRun, ...
                  t_tlo_meta, t_fdia_meta, alpha_meta, acc_meta, string(lines_str), anchor_meta, num_lines_meta, ...
                  run.noise.rtu.bus_sigma, run.noise.rtu.flow_sigma, run.noise.rtu.rho, run.noise.rtu.bias_std, ...
                  run.noise.pmu.theta_sigma, run.noise.pmu.bias_std, ...
                  numel(PMU_BUSES), pmu_ratio, string(mat2str(PMU_BUSES(:)')), ...
                  run.faults_stats.RTU_outlier_rate, run.faults_stats.RTU_missing_rate, run.faults_stats.RTU_stuck_rate, ...
                  run.faults_stats.PMU_outlier_rate, run.faults_stats.PMU_missing_rate, run.faults_stats.PMU_stuck_rate, ...
                  'VariableNames', {'Run_ID','Split','ClassName','RetriesUsed', ...
                                    'NumWindowsRun', ...
                                    'TLO_t0','FDIA_t0','CCPA_alpha','Attack_access_ratio','TLO_lines','TLO_AnchorLine','TLO_NumLines', ...
                                    'RTU_bus_sigma','RTU_flow_sigma','RTU_rho','RTU_bias_std', ...
                                    'PMU_theta_sigma','PMU_bias_std', ...
                                    'PMU_count','PMU_ratio','PMU_buses', ...
                                    'RTU_outlier_rate','RTU_missing_rate','RTU_stuck_rate', ...
                                    'PMU_outlier_rate','PMU_missing_rate','PMU_stuck_rate'});
    append_csv(Tmeta, FN_META);

    for w = 1:numel(WinList)
        WIN_COUNTER = WIN_COUNTER + 1;
        win_id = WIN_COUNTER;

        win_class = string(WinClassList(w));
        ci = find(CLASS_NAMES == win_class, 1);
        if isempty(ci), ci = 1; end
        SampleWeight = 1 / max(1, classCounts(ci));

        Tsplit = table(win_id, r, split_tag, win_class, NumWindowsRun, SampleWeight, ...
                       'VariableNames', {'Window_ID','Run_ID','Split','WindowClassName','NumWindowsRun','SampleWeight'});
        append_csv(Tsplit, FN_SPLIT);

        ydet = YdList{w};
        yloc = YlList{w};

        Tlab = table(win_id, 'VariableNames', {'Window_ID'});
        for ii = 1:numel(det_cols), Tlab.(det_cols{ii}) = ydet(ii); end
        for jj = 1:numel(loc_cols), Tlab.(loc_cols{jj}) = yloc(jj); end
        append_csv(Tlab, FN_LABELS);

        ts = idxList{w}.ts; te = idxList{w}.te;

        cyber_on = false(T_WIN,1);
        for s = 1:T_WIN
            tt = ts + s - 1;
            cyber_on(s) = is_cyber_active_time(run, tt);
        end

        if any(cyber_on)
            CyberStartStep = find(cyber_on, 1, 'first');
            CyberEndStep   = find(cyber_on, 1, 'last');
            bus_mask_w = run.cyber.bus_mask(:);
            br_mask_w  = run.cyber.branch_mask(:);
        else
            CyberStartStep = 0;
            CyberEndStep   = 0;
            bus_mask_w = zeros(N,1);
            br_mask_w  = zeros(L,1);
        end

        Tcy = table(win_id, CyberStartStep, CyberEndStep, 'VariableNames', {'Window_ID','CyberStartStep','CyberEndStep'});
        for i = 1:N, Tcy.(cyber_bus_cols{i}) = bus_mask_w(i); end
        for e = 1:L, Tcy.(cyber_branch_cols{e}) = br_mask_w(e); end
        append_csv(Tcy, FN_CYBER);
    end

    if ~RESTORE_LABELS_ONLY

        for w = 1:numel(WinList)
            win_id = WIN_COUNTER - (numel(WinList)-w);
            ts = idxList{w}.ts;

            for s = 1:T_WIN
                t  = ts + s - 1;

                theta_pmu = run.pmu_theta_meas{t};
                pmu_avail = double(run.pmu_mask);

                rtu_pinj       = run.rtu_pinj_meas{t};

                pinj_wls_pre   = run.pinj_est_wls_pre{t};
                resid_pre      = repmat(run.wls_resid_pre(t),  N, 1);

                Window_ID = repmat(win_id, N,1);
                Step      = repmat(s, N,1);
                BusIndex  = (1:N)';

                Tnodes = table(Window_ID, Step, BusIndex, ...
                               theta_pmu, pmu_avail, rtu_pinj, ...
                               pinj_wls_pre, resid_pre, ...
                               'VariableNames', {'Window_ID','Step','BusIndex', ...
                                                 'PMU_Theta_meas_rad','PMU_Avail', ...
                                                 'RTU_Pinj_meas', ...
                                                 'Pinj_est_WLS_preTopo', ...
                                                 'WLS_ResidRMS_preTopo'});
                append_csv(Tnodes, FN_NODES);
            end
        end

        fbus = mpc0.branch(:, F_BUS);
        tbus = mpc0.branch(:, T_BUS);

        for w = 1:numel(WinList)
            win_id = WIN_COUNTER - (numel(WinList)-w);
            ts = idxList{w}.ts;

            for s = 1:T_WIN
                t  = ts + s - 1;

                rtu_pflow = run.rtu_pflow_meas{t};

                th = run.pmu_theta_meas{t};
                pmu_dtheta = NaN(L,1);
                pmu_av = false(L,1);

                for ell = 1:L
                    fb = fbus(ell);
                    tb = tbus(ell);
                    if ~isnan(th(fb)) && ~isnan(th(tb))
                        pmu_dtheta(ell) = th(fb) - th(tb);
                        pmu_av(ell) = true;
                    end
                end

                Window_ID = repmat(win_id, L,1);
                Step      = repmat(s, L,1);
                BranchID  = (1:L)';

                Tbr = table(Window_ID, Step, BranchID, ...
                            rtu_pflow, double(pmu_av), pmu_dtheta, fbus, tbus, ...
                            'VariableNames', {'Window_ID','Step','BranchID', ...
                                              'RTU_Pflow_meas','PMU_Avail','PMU_Dtheta_meas_rad', ...
                                              'F_BUS','T_BUS'});
                append_csv(Tbr, FN_BRANCH);
            end
        end

        for w = 1:numel(WinList)
            win_id = WIN_COUNTER - (numel(WinList)-w);
            ts = idxList{w}.ts;
            for s = 1:T_WIN
                t  = ts + s - 1;
                if isempty(run.gen_res{t}), continue; end
                G = run.gen_res{t};
                Window_ID = repmat(win_id, size(G,1), 1);
                Step = repmat(s, size(G,1), 1);
                GenID = (1:size(G,1))';
                Tgen = table(Window_ID, Step, GenID);
                for kcol = 1:size(G,2)
                    Tgen.(sprintf('gen_col_%d',kcol)) = G(:,kcol);
                end
                append_csv(Tgen, FN_GENS);
            end
        end
    end

    else

    end

end

if isfile(FN_META)
    write_line_coverage_report(FN_META, FN_LINE_COVERAGE, ...
        ELIGIBLE_TLO_LINES, INELIGIBLE_TLO_LINES, COVERAGE_ASSERT_ENABLE);
end

if EXPORT_RAW
    assert(isfile(FN_RAW_NODES),  'Missing raw_nodes output.');
    assert(isfile(FN_RAW_BRANCH), 'Missing raw_branches output.');
    assert(isfile(FN_RAW_LABELS), 'Missing raw_labels output.');
    assert(isfile(FN_META),       'Missing runs_metadata output.');

    node_vars_check = csv_header_vars(FN_RAW_NODES);
    br_vars_check   = csv_header_vars(FN_RAW_BRANCH);
    meta_vars_check = csv_header_vars(FN_META);

    assert(ismember('Theta_est_WLS_RTUonly', node_vars_check) && ...
           ismember('WLS_ResidRMS_RTUonly', node_vars_check), ...
        'Corrected RTU-only WLS columns are missing from raw_nodes.');
    assert(ismember('CandidateRTURMS', br_vars_check) && ...
           ismember('CandidateRTUImprovement', br_vars_check) && ...
           ismember('CandidateRTURank', br_vars_check), ...
        'Corrected RTU-only candidate columns are missing from raw_branches.');

    assert(ismember('Theta_est_WLS_preTopo', node_vars_check), ...
        'Theta_est_WLS_preTopo missing from raw_nodes output.');
    assert(ismember('Pflow_est_WLS_preTopo', br_vars_check), ...
        'Pflow_est_WLS_preTopo missing from raw_branches output.');
    assert(all(ismember({'Resid_Pinj_JointWLS','NormResid_Pinj_JointWLS', ...
                         'Resid_Pinj_RTUonlyWLS','PMU_ThetaResid_JointWLS'}, node_vars_check)), ...
        'v11 per-bus residual/PMU features are missing from raw_nodes.');
    assert(all(ismember({'CandidateJointImprovement','CandidateRTUImprovement', ...
                         'CandidateJointRank','PMU_Pflow_est'}, br_vars_check)), ...
        'v11 candidate-topology/PMU-flow features are missing from raw_branches.');
    assert(ismember('BaseState_ID', node_vars_check) && ismember('BaseState_ID', br_vars_check), ...
        'Counterfactual BaseState_ID is missing from raw feature tables.');
    assert(ismember('TLO_AnchorLine', meta_vars_check) && ismember('TLO_NumLines', meta_vars_check) && ...
           ismember('BaseState_ID', meta_vars_check) && ismember('PhysicalEffectL2', meta_vars_check), ...
        'v11 anchor/counterfactual/difficulty metadata columns are missing.');
    if ENRICH.export_truth_targets
        assert(isfile(FN_RAW_TRUTH_NODES) && isfile(FN_RAW_TRUTH_BRANCH), ...
            'TARGET-ONLY truth exports are missing.');
        assert(contains(FN_RAW_TRUTH_NODES,'target_only') && contains(FN_RAW_TRUTH_BRANCH,'target_only'), ...
            'Truth files must remain explicitly named target_only.');
    end
    assert(isfile(FN_LINE_ELIGIBILITY), 'Missing line eligibility report.');
    assert(isfile(FN_LINE_COVERAGE), 'Missing line coverage report.');
    assert(isfile(FN_REFERENCE_AUDIT), 'Missing reference compliance report.');

end
fprintf('Final dataset outputs saved for %s.\n', CASE_TAG);
