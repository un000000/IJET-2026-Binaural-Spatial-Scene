function [room_configs] = generate_room_configs(config_file)
% GENERATE_ROOM_CONFIGS  Generate room/receiver configs from explicit room_pairs.
%
% Each entry in "room_pairs" in the JSON binds exactly one room size to
% exactly one reverb profile - no Cartesian product is computed.
% The outer loop is over every SOFA file discovered under
%   hrtf_13_resampled/<institute>/*.sofa
% so every room_pair is generated for each available HRTF.
%
% Output struct fields (per config):
%   Room, Receivers, dimensions, center, reverb_id,
%   room_id    - room_pair index (1..num_pairs); identifies the physical room
%   institute  - name of the HRTF institute folder (e.g. 'sadie', 'aachen')
%   hrir_id    - SOFA filename without extension
%   hrir_data  - normalised HRIR struct (hrir_l, hrir_r, az, el)

% -------------------------------------------------------------------------
% Read JSON
% -------------------------------------------------------------------------
config = jsondecode(fileread(config_file));

room_pairs      = config.room_pairs;          % array of {dimensions, reverb_profile}
frequencies     = config.reverb_profiles.frequencies;
ear_separation  = config.receiver_config.ear_separation;
receiver_height = config.receiver_config.height;

num_pairs = length(room_pairs);

% -------------------------------------------------------------------------
% Discover SOFA files:  hrtf_13_resampled/<institute>/*.sofa
% -------------------------------------------------------------------------
hrtf_root    = './hrtf_13_resampled';
inst_entries = dir(hrtf_root);
inst_dirs    = inst_entries([inst_entries.isdir] & ...
                            ~ismember({inst_entries.name}, {'.', '..'}));

if isempty(inst_dirs)
    error(['No institute subfolders found in: %s\n' ...
           'Expected layout: %s/<institute>/*.sofa'], hrtf_root, hrtf_root);
end

% Flatten every (institute, sofa file) pair into a single list. Institutes
% and files are sorted by name so the global load order (and hence the
% numeric hrir_id) is deterministic across runs and machines.
[~, inst_order] = sort({inst_dirs.name});
inst_dirs = inst_dirs(inst_order);

hrtf_files = struct('institute', {}, 'path', {}, 'name', {});
for i = 1:numel(inst_dirs)
    institute = inst_dirs(i).name;
    sofas     = dir(fullfile(hrtf_root, institute, '*.sofa'));
    if ~isempty(sofas)
        [~, sofa_order] = sort({sofas.name});   % deterministic within institute
        sofas = sofas(sofa_order);
    end
    for s = 1:numel(sofas)
        hrtf_files(end+1) = struct( ...
            'institute', institute, ...
            'path',      fullfile(hrtf_root, institute, sofas(s).name), ...
            'name',      sofas(s).name); %#ok<AGROW>
    end
end

if isempty(hrtf_files)
    error(['No .sofa files found under: %s/<institute>/\n' ...
           'Place SimpleFreeFieldHRIR SOFA files there.\n' ...
           'Requires the SOFA MATLAB API (SOFAload) on the path.'], hrtf_root);
end

num_hrirs     = numel(hrtf_files);
total_configs = num_pairs * num_hrirs;

fprintf('Found %d SOFA file(s) under %s/<institute>/\n', num_hrirs, hrtf_root);
fprintf('Generating %d room configurations (%d pairs x %d HRTFs)...\n', ...
        total_configs, num_pairs, num_hrirs);

room_configs = struct('Room', {}, 'Receivers', {}, 'dimensions', {}, ...
                      'center', {}, 'reverb_id', {}, 'room_id', {}, ...
                      'institute', {}, 'hrir_id', {}, 'hrir_data', {});
config_idx = 1;

% -------------------------------------------------------------------------
% Outer loop: SOFA files
% -------------------------------------------------------------------------
for hrir_idx = 1:num_hrirs
    sofa_path = hrtf_files(hrir_idx).path;
    institute = hrtf_files(hrir_idx).institute;
    hrir_id   = hrir_idx;   % global load-order index (1..num_hrirs)

    fprintf('  Loading HRTF [%d/%d] (id %d): %s/%s\n', hrir_idx, num_hrirs, ...
            hrir_id, institute, hrtf_files(hrir_idx).name);

    Obj = SOFAload(sofa_path);

    if size(Obj.Data.IR, 2) < 2
        warning('Skipping %s/%s: expected 2 receiver channels (binaural).', ...
                institute, hrtf_files(hrir_idx).name);
        continue;
    end

    hrir_l = squeeze(Obj.Data.IR(:, 1, :));   % [M x N]
    hrir_r = squeeze(Obj.Data.IR(:, 2, :));   % [M x N]
    hrtf_fs = Obj.Data.SamplingRate;

    fs_sim = config.simulation_config.fs;     % target simulation fs
    if hrtf_fs ~= fs_sim
        fprintf('    Resampling HRTF from %d Hz to %d Hz\n', hrtf_fs, fs_sim);
        hrir_l = resample(hrir_l', fs_sim, hrtf_fs)';   % resample expects [N x M], transpose in/out
        hrir_r = resample(hrir_r', fs_sim, hrtf_fs)';
        hrtf_fs = fs_sim;
    end

    az_raw  = Obj.SourcePosition(:, 1);
    el_meas = Obj.SourcePosition(:, 2);
    az_meas = mod(az_raw + 180, 360) - 180;   % remap 0-360 -> -180..180

    Direction = [az_meas, el_meas];

    hrir_data_norm.hrir_l = hrir_l;
    hrir_data_norm.hrir_r = hrir_r;
    hrir_data_norm.az     = az_meas;
    hrir_data_norm.el     = el_meas;

    % -----------------------------------------------------------------------
    % Inner loop: room_pairs (each pair = one size + one reverb profile)
    % -----------------------------------------------------------------------
    for pair_idx = 1:num_pairs
        pair        = room_pairs(pair_idx);
        dims        = pair.dimensions;            % [width, depth, height]
        reverb_id   = pair.reverb_profile;        % e.g. 'a', 'b', ...
        reverb_data = config.reverb_profiles.profiles.(reverb_id);

        width  = dims(1);
        depth  = dims(2);
        height = dims(3);

        center_x = width  / 2;
        center_y = depth  / 2;
        center_z = receiver_height;

        left_ear  = [center_x - ear_separation/2, center_y, center_z];
        right_ear = [center_x + ear_separation/2, center_y, center_z];

        Receivers = [];
        Receivers = AddReceiver(Receivers, ...
            'Type',        'impulse', ...
            'Location',    left_ear, ...
            'Orientation', [90, 0, 0], ...
            'Direction',   Direction, ...
            'Fs',          hrtf_fs, ...
            'Response',    hrir_l);
        Receivers = AddReceiver(Receivers, ...
            'Type',        'impulse', ...
            'Location',    right_ear, ...
            'Orientation', [90, 0, 0], ...
            'Direction',   Direction, ...
            'Fs',          hrtf_fs, ...
            'Response',    hrir_r);

        Room = SetupRoom('Dim',        [width, depth, height], ...
                         'Freq',       frequencies, ...
                         'Absorption', reverb_data.absorption, ...
                         'Scattering', reverb_data.scattering);

        room_configs(config_idx).Room       = Room;
        room_configs(config_idx).Receivers  = Receivers;
        room_configs(config_idx).dimensions = [width, depth, height];
        room_configs(config_idx).center     = [center_x, center_y, center_z];
        room_configs(config_idx).reverb_id  = reverb_id;
        room_configs(config_idx).room_id    = pair_idx;
        room_configs(config_idx).institute  = institute;
        room_configs(config_idx).hrir_id    = hrir_id;
        room_configs(config_idx).hrir_data  = hrir_data_norm;

        config_idx = config_idx + 1;
    end
end

fprintf('Generated %d room configurations successfully.\n', length(room_configs));
end
