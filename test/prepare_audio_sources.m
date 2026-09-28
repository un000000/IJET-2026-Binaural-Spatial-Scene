function prepare_audio_sources()
% PREPARE_AUDIO_SOURCES  Extract one 10-second excerpt from each source file.
%
% Processes several raw input roots (song, speech, ...). Each root contains
% set folders (set1, set2, ...), and each set folder must hold exactly 6 audio
% files (.wav, .flac or .mp3). For every file a single 10-second excerpt
% (seconds 1–11) is taken, converted to mono, resampled to the target rate and
% peak-normalised. Output is always written as .wav.
%
% Output is written to ./processed_audio, one folder per set, named
% "<rawRootName>_<setName>"  e.g. raw_audio_speech_set1.

% --- Input roots (add more here) -------------------------------------
raw_dirs = { ...
    'D:\KW\corpuses\ALL_MUSIC', ...
};

processed_dir = 'D:\KW\ALL_MUSIC_PROCESSED';

% --- Excerpt definition (one 10-second clip) -------------------------
excerpt_start_s = 0;      % excerpt spans [1, 11] s  → exactly 10 seconds
excerpt_end_s   = 10;
required_files  = 6;      % every set folder must contain exactly this many audio files

% --- Audio target parameters -----------------------------------------
target_fs       = 48000;
target_peak_db  = -3;
target_peak_lin = 10^(target_peak_db / 20);

% =====================================================================
%  Pre-flight validation: gather every set folder and verify file count
% =====================================================================
jobs      = struct('root_name', {}, 'set_name', {}, 'set_path', {});
offenders = {};

for d = 1:numel(raw_dirs)
    raw_dir = raw_dirs{d};
    if ~exist(raw_dir, 'dir')
        error('Input root not found: %s', raw_dir);
    end
    [~, root_name] = fileparts(raw_dir);          % e.g. 'raw_audio_speech'

    entries     = dir(raw_dir);
    set_folders = entries([entries.isdir] & ...
                          ~strcmp({entries.name}, '.') & ...
                          ~strcmp({entries.name}, '..'));
    if isempty(set_folders)
        error('No set subfolders found in %s', raw_dir);
    end

    for s = 1:numel(set_folders)
        set_name = set_folders(s).name;
        set_path = fullfile(raw_dir, set_name);
        n_audio  = numel(list_audio_files(set_path));

        if n_audio < required_files
            offenders{end+1} = sprintf('  %s  (%d audio files)', set_path, n_audio); %#ok<AGROW>
            continue;
        end

        jobs(end+1) = struct('root_name', root_name, ...
                             'set_name',  set_name, ...
                             'set_path',  set_path); %#ok<AGROW>
    end
end

fprintf('Validation passed: %d set folder(s), each with at least %d audio files.\n\n', ...
        numel(jobs), required_files);

% --- Create top-level output directory --------------------------------
if ~exist(processed_dir, 'dir')
    mkdir(processed_dir);
    fprintf('Created output directory: %s\n', processed_dir);
end

% =====================================================================
%  Main loop – one iteration per set folder
% =====================================================================
for j = 1:numel(jobs)
    job = jobs(j);

    out_folder_name = sprintf('%s_%s', job.root_name, job.set_name);  % raw_audio_speech_set1
    out_folder_path = fullfile(processed_dir, out_folder_name);
    if ~exist(out_folder_path, 'dir')
        mkdir(out_folder_path);
    end

    audio_files = list_audio_files(job.set_path);
    if numel(audio_files) > required_files
        idx = randperm(numel(audio_files), required_files);
        audio_files = audio_files(idx);
    end

    fprintf('=== [%d/%d] %s  ->  %s ===\n', ...
            j, numel(jobs), job.set_path, out_folder_name);

    % -----------------------------------------------------------------
    %  File loop – extract the single 10-second excerpt
    % -----------------------------------------------------------------
    for w = 1:numel(audio_files)
        in_file        = fullfile(job.set_path, audio_files(w).name);
        [~, base_name] = fileparts(audio_files(w).name);
        out_file       = fullfile(out_folder_path, [base_name, '.wav']);  % always .wav

        fprintf('  [%d/%d] %s ... ', w, numel(audio_files), audio_files(w).name);

        try
            file_info   = audioinfo(in_file);
            native_fs   = file_info.SampleRate;
            total_samps = file_info.TotalSamples;

            % Convert the fixed [1, 11] s excerpt to sample indices
            s1 = max(1,           round(excerpt_start_s * native_fs) + 1);
            s2 = min(total_samps, round(excerpt_end_s   * native_fs));

            if s1 >= s2
                fprintf('SKIP (file too short for a 10 s excerpt)\n');
                continue;
            end

            % Read only the excerpt
            [x, fs] = audioread(in_file, [s1, s2]);

            % Mono
            if size(x, 2) > 1
                x = mean(x, 2);
            end

            % Resample to target rate
            if fs ~= target_fs
                x = resample(x, target_fs, fs);
            end

            % Peak-normalise
            pk = max(abs(x));
            if pk > 0
                x = x * (target_peak_lin / pk);
            end

            % Write (always .wav)
            audiowrite(out_file, x, target_fs);

            out_info = audioinfo(out_file);
            fprintf('OK  (%.2f s, %d Hz, %dch)\n', ...
                    out_info.Duration, out_info.SampleRate, out_info.NumChannels);

        catch ME
            fprintf('ERROR - %s\n', ME.message);
        end
    end % file loop

    fprintf('\n');
end % job loop

fprintf('=== ALL DONE ===\n');
fprintf('Processed %d set folder(s). Output saved to: %s\n', numel(jobs), processed_dir);
end


% =========================================================================
%  LOCAL HELPERS
% =========================================================================
function files = list_audio_files(folder)
% Return a dir-style struct of all supported audio files in FOLDER,
% sorted by name so the ordering is deterministic across formats.
exts  = {'*.wav', '*.flac', '*.mp3'};
files = [];
for e = 1:numel(exts)
    files = [files; dir(fullfile(folder, exts{e}))]; %#ok<AGROW>
end
if ~isempty(files)
    [~, order] = sort({files.name});
    files = files(order);
end
end
