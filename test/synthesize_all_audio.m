function synthesize_all_audio(room_config_file, source_config_file, input_dir, output_dir)
% SYNTHESIZE_ALL_AUDIO  Batch BRIR synthesis over audio folders x rooms x HRTFs.
%
% HRTF handling lives in generate_room_configs: it scans
%   hrtf_13_resampled/<institute>/*.sofa
% and returns one room_config per (room_pair x SOFA file), each already
% carrying its own Receivers plus .institute / .hrir_id / .room_id. This
% loop therefore just iterates room_configs and reads those fields for the
% output filename - no separate HRTF loop is needed here.

source_config    = jsondecode(fileread(source_config_file));
room_config_data = jsondecode(fileread(room_config_file));

max_rooms = inf;

if ~exist(output_dir, 'dir'), mkdir(output_dir); end

fs_rir      = room_config_data.simulation_config.fs;
target_lufs = source_config.output_config.normalization_target_lufs;

processed_dir = input_dir;
noise_dir     = 'D:/KW/SPEECH_PREPROCESSED';

% -------------------------------------------------------------------------
% Discover processed song folders
% -------------------------------------------------------------------------
folder_entries = dir(processed_dir);
song_folders   = folder_entries([folder_entries.isdir] & ...
                                ~strcmp({folder_entries.name}, '.') & ...
                                ~strcmp({folder_entries.name}, '..'));
if isempty(song_folders)
    error('No subfolders found in %s', processed_dir);
end

% -------------------------------------------------------------------------
% Noise pool
% -------------------------------------------------------------------------
noise_listing = dir(fullfile(noise_dir, '*.wav'));
if isempty(noise_listing)
    %error('No noise files found in %s', noise_dir); %todo
end

% -------------------------------------------------------------------------
% Room configurations (one per room_pair x SOFA file, HRTF baked in)
% -------------------------------------------------------------------------
room_configs = generate_room_configs(room_config_file);
num_rooms    = min(length(room_configs), max_rooms);

Options = MCRoomSimOptions( ...
    'SimSpec',  room_config_data.simulation_config.sim_spec, ...
    'SimDiff',  room_config_data.simulation_config.sim_diff, ...
    'Duration', room_config_data.simulation_config.duration, ...
    'Order',    room_config_data.simulation_config.order, ...
    'Fs',       fs_rir, ...
    'Verbose',  false);

fprintf('========================================\n');
fprintf('3D AUDIO BATCH SYNTHESIZER\n');
fprintf('Song folders            : %d\n', length(song_folders));
fprintf('Room configs (incl HRTF): %d\n', num_rooms);
fprintf('========================================\n');

total_processed = 0;
start_time      = tic;

% =========================================================================
% Outer loop: one iteration per processed audio folder
% =========================================================================
for folder_idx = 1:44

    folder_name = song_folders(folder_idx).name;
    folder_path = fullfile(processed_dir, folder_name);

    wav_files = dir(fullfile(folder_path, '*.wav'));
    if isempty(wav_files)
        fprintf('Skipping %s (no .wav files)\n', folder_name);
        continue;
    end

    num_songs = length(wav_files);
    fprintf('\n=== Folder [%d/%d]: %s  (%d tracks) ===\n', ...
            folder_idx, length(song_folders), folder_name, num_songs);

    % --- Load and preprocess all song signals once per folder ------------
    song_signals = cell(num_songs, 1);
    for i = 1:num_songs
        [x, fs] = audioread(fullfile(folder_path, wav_files(i).name));
        if size(x, 2) > 1, x = mean(x, 2); end
        if fs ~= fs_rir,   x = resample(x, fs_rir, fs); end
        song_signals{i} = x;
    end
    min_song_len = min(cellfun(@numel, song_signals));
    song_signals = cellfun(@(s) s(1:min_song_len), song_signals, 'UniformOutput', false);

    % =====================================================================
    % Room loop (each room_config = room_pair x HRTF)
    % =====================================================================
    parfor room_idx = 1:num_rooms
        room_config = room_configs(room_idx);

        fprintf('\n  Room %d/%d  [%s | %s/id%d | %.0fx%.0fx%.0f m]\n', ...
                room_idx, num_rooms, room_config.reverb_id, ...
                room_config.institute, room_config.hrir_id, ...
                room_config.dimensions(1), room_config.dimensions(2), ...
                room_config.dimensions(3));

        % Generate all arc/mode combos for this room using the proper function.
        % Pass num_songs so source counts are correct for this folder.
        src_configs = generate_source_configs(source_config_file, ...
                                              room_config.center, ...
                                              room_config.dimensions, ...
                                              num_songs);

        for src_idx = 1:length(src_configs)
            src_config      = src_configs(src_idx);
            arc_mode        = src_config.arc_mode;
            arc_angle       = src_config.arc_angle;

            % --------------------------------------------------------------
            % Filename (computed first so existing outputs can be skipped
            % cheaply - no RIR compute, no synthesis, no write):
            %   <folder-name>###<institute>_<hrtfID>_<arcAngle>_<roomID>_<mode>.wav
            % --------------------------------------------------------------
            brir_filename = generate_filename(folder_name, room_config.institute, ...
                                room_config.hrir_id, arc_angle, arc_mode, room_config.room_id);
            brir_path = fullfile(output_dir, brir_filename);

            if exist(brir_path, 'file')
                fprintf('    [skip, exists] %s\n', brir_filename);
                continue;
            end

            % --------------------------------------------------------------
            % Assemble signal list to match Sources order:
            %   front_and_back : song signals only (floor(N/2) front + back)
            %   front_only     : all songs, then 1 noise track
            %   back_only      : all songs, then 1 noise track
            % --------------------------------------------------------------
            dry_dont_use_noise = 1;
            if dry_dont_use_noise == 1
                all_signals = song_signals;
            elseif strcmp(arc_mode, 'FF')
                % Keep ALL songs (fixes the 7 -> 6 issue)
                all_signals = song_signals;

                % Load noise (same as in else branch)
                noise_pick  = randi(length(noise_listing));
                [xn, fsn]   = audioread(fullfile(noise_dir, ...
                                        noise_listing(noise_pick).name));
                if size(xn, 2) > 1, xn = mean(xn, 2); end
                if fsn ~= fs_rir,  xn = resample(xn, fs_rir, fsn); end
                xn = fit_length(xn, min_song_len);

                % Insert noise at random position
                insert_idx  = randi(length(all_signals) + 1);
                all_signals = [all_signals(1:insert_idx-1); {xn}; all_signals(insert_idx:end)];

            else  % front_only / back_only
                noise_pick  = randi(length(noise_listing));
                [xn, fsn]   = audioread(fullfile(noise_dir, ...
                                        noise_listing(noise_pick).name));
                if size(xn, 2) > 1, xn = mean(xn, 2); end
                if fsn ~= fs_rir,  xn = resample(xn, fs_rir, fsn); end
                xn = fit_length(xn, min_song_len);

                insert_idx  = randi(length(song_signals) + 1);
                all_signals = [song_signals(1:insert_idx-1); {xn}; song_signals(insert_idx:end)];
            end

            % Trim all signals to the same length
            sig_len     = min(cellfun(@numel, all_signals));
            all_signals = cellfun(@(s) s(1:sig_len), all_signals, 'UniformOutput', false);

            if rand() < 0.2 
                elapsed = toc(start_time);
                fprintf('    [%.1f min]\n', elapsed/60);
            end

            % --------------------------------------------------------------
            % BRIR synthesis
            % --------------------------------------------------------------
            try
                synthesize_brir(src_config.Sources, ...
                    room_config.Receivers, ...
                    room_config.Room, ...
                    Options, ...
                    all_signals, ...
                    brir_path, ...
                    fs_rir, target_lufs);
                total_processed = total_processed + 1;
            catch ME
    fprintf(2, '\n[BRIR ERROR] %s: %s\n', brir_filename, ME.message);
    fprintf(2, '    Sources = %d, signals = %d\n', ...
        length(src_config.Sources), length(all_signals));

    if exist('RIR', 'var')
        fprintf(2, '    RIR size = %s\n', mat2str(size(RIR)));
    end

    for s = 1:length(ME.stack)
        fprintf(2, '    %s, line %d\n', ...
            ME.stack(s).name, ME.stack(s).line);
    end
end

        end % src_configs loop
    end % room loop
end % folder loop

total_time = toc(start_time);
fprintf('\n========================================\n');
fprintf('SYNTHESIS COMPLETE\n');
fprintf('Configurations processed : %d\n',       total_processed);
fprintf('Total time               : %.1f min\n', total_time / 60);
fprintf('BRIR output              : %s\n',        output_dir);
fprintf('========================================\n');
end


% =========================================================================
% LOCAL HELPERS
% =========================================================================

function x = fit_length(x, target_len)
if numel(x) < target_len
    reps = ceil(target_len / numel(x));
    x    = repmat(x, reps, 1);
end
x = x(1:target_len);
end

function filename = generate_filename(folder_name, institute, hrtf_id, arc_angle, mode, room_idx)
% GENERATE_FILENAME  Output format:
%   <folder-name>###<institute>_<hrtfID>_<arcAngle>_<roomID>_<mode>.wav
% Underscores in the folder name are converted to hyphens so that the
% "###" prefix and the "_"-separated metadata stay unambiguous.
folder_clean = strrep(folder_name, '_', '-');
filename = sprintf('%s###%s_hrtf%d_angle%03d_room%02d_%s.wav', ...
                   folder_clean, institute, hrtf_id, arc_angle, room_idx, mode);
end


% =========================================================================
function synthesize_brir(Sources, Receivers, Room, Options, signals, output_path, fs_rir, target_lufs)
% SYNTHESIZE_BRIR  Room simulation + HRTF convolution
%
% Uses MCRoomSim to compute BRIRs, then convolves each source signal
% with the corresponding left/right RIR and sums to a stereo mix.

RIR = cached_run_mc_room_sim(Sources, Receivers, Room, Options);

% todo
dry_run = 1;
if dry_run == 1
    return;
end

max_rir_len = max(cellfun(@(h) length(h), RIR(:)));
output_len  = length(signals{1}) + max_rir_len - 1;
yL = zeros(output_len, 1);
yR = zeros(output_len, 1);

% Randomly assign signals to source positions
perm = randperm(length(Sources));
signals_shuffled = signals(perm);

for k = 1:length(Sources)
    yL_k = fftfilt(RIR{1, k}, signals_shuffled{k});
    yR_k = fftfilt(RIR{2, k}, signals_shuffled{k});
    yL(1:length(yL_k)) = yL(1:length(yL_k)) + yL_k;
    yR(1:length(yR_k)) = yR(1:length(yR_k)) + yR_k;
end

fadeTimeSeconds = 0.01;
maxLengthSeconds = 7.0;

y_stereo = normalize_loudness([yL, yR], fs_rir, target_lufs);

% Keep 7 seconds from 1.0 s to 8.0 s after BRIR synthesis
startTimeSeconds = 1.0;
durationSeconds  = 7.0;

startSample = floor(startTimeSeconds * fs_rir) + 1;
numSamples  = floor(durationSeconds * fs_rir);
endSample   = startSample + numSamples - 1;

if size(y_stereo, 1) < endSample
    error('Synthesized audio is shorter than 8 seconds.');
end

y_stereo = y_stereo(startSample:endSample, :);

nFade   = round(fs_rir * fadeTimeSeconds);
fadeWin = linspace(0, 1, nFade).';
y_stereo(1:nFade, :)              = y_stereo(1:nFade, :) .* fadeWin;
y_stereo(end-nFade+1:end, :)      = y_stereo(end-nFade+1:end, :) .* flipud(fadeWin);
audiowrite(output_path, y_stereo, fs_rir);
fprintf('Saved audio to: %s\n', output_path);
end


function RIR = cached_run_mc_room_sim(Sources, Receivers, Room, Options)
% CACHED_RUN_MC_ROOM_SIM  Memoised wrapper around RunMCRoomSim.
%
% The cache key is built from Sources, Receivers, Room, and Options.
% Within a single MATLAB session the persistent Map keeps results in memory.
% A .mat sidecar file makes the cache survive across sessions.

%persistent cache;
%if isempty(cache)
%    cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
%end

cache_key = build_rir_cache_key(Sources, Receivers, Room, Options);

% --- in-memory hit ---
%if cache.isKey(cache_key)
    %RIR = cache(cache_key);
    %fprintf('    [RIR cache HIT  - memory] %s\n', cache_key);
    %return;
%end

% --- on-disk hit ---
rir_cache_dir_base = 'D:/KW/RIR_cache/';
cache_dir  = fullfile(rir_cache_dir_base, 'mc_room_sim_cache');
if ~exist(cache_dir, 'dir'), mkdir(cache_dir); end
cache_file = fullfile(cache_dir, [cache_key, '.mat']);

if exist(cache_file, 'file')
    loaded = load(cache_file, 'RIR');
    RIR    = loaded.RIR;
    if size(RIR,1) == 2 && size(RIR,2) == 6
        %cache(cache_key) = RIR;             % promote to memory
        fprintf('    [RIR cache HIT  - disk  ] %s\n', cache_key);
        return;
    end
end

% --- cache miss: compute and store ---
fprintf('    [RIR cache MISS - computing ] %s %d %f\n', cache_key, size(Sources, 2), Room.Dim(1));
RIR = RunMCRoomSim(Sources, Receivers, Room, Options);
%cache(cache_key) = RIR;
save(cache_file, 'RIR');
end


function key = build_rir_cache_key(Sources, Receivers, Room, Options)
% Serialise inputs to a short hex string using MATLAB's DataHash-style
% approach via the undocumented but stable getByteStreamFromArray.
raw  = getByteStreamFromArray({Sources, Receivers, Room, Options});
md   = java.security.MessageDigest.getInstance('MD5');
md.update(raw);
bytes = typecast(md.digest(), 'uint8');
key  = sprintf('%02x', bytes);          % 32-char hex string
end
