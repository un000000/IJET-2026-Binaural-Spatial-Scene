function batch_synthesize(room_config_file, source_config_file, batch_id, total_batches)
% BATCH_SYNTHESIZE Process a subset of configurations for parallel execution
%
% This function divides the total workload into batches for parallel processing
% on multiple cores or cluster nodes.
%
% Inputs:
%   room_config_file - path to room configuration JSON
%   source_config_file - path to source configuration JSON  
%   batch_id - current batch number (1 to total_batches)
%   total_batches - total number of batches to divide work into
%
% Example usage on a cluster:
%   % On node 1: process batch 1 of 10
%   batch_synthesize('config_rooms.json', 'config_sources.json', 1, 10);
%   
%   % On node 2: process batch 2 of 10
%   batch_synthesize('config_rooms.json', 'config_sources.json', 2, 10);
%   
%   % etc.
%
% For MATLAB Parallel Computing Toolbox:
%   parfor batch_id = 1:10
%       batch_synthesize('config_rooms.json', 'config_sources.json', batch_id, 10);
%   end

fprintf('========================================\n');
fprintf('BATCH PROCESSOR - Batch %d of %d\n', batch_id, total_batches);
fprintf('========================================\n');

% Load configurations
source_config = jsondecode(fileread(source_config_file));
output_dir = source_config.output_config.output_directory;

% Create batch-specific subdirectory
batch_output_dir = fullfile(output_dir, sprintf('batch_%03d', batch_id));
if ~exist(batch_output_dir, 'dir')
    mkdir(batch_output_dir);
end

% Load room configurations
fprintf('\nLoading room configurations...\n');
room_configs = generate_room_configs(room_config_file);
total_rooms = length(room_configs);

% Divide rooms among batches
rooms_per_batch = ceil(total_rooms / total_batches);
start_room = (batch_id - 1) * rooms_per_batch + 1;
end_room = min(batch_id * rooms_per_batch, total_rooms);

if start_room > total_rooms
    fprintf('No rooms to process in this batch.\n');
    return;
end

fprintf('This batch will process rooms %d to %d (of %d total)\n', ...
        start_room, end_room, total_rooms);

% Load simulation parameters
config = jsondecode(fileread(room_config_file));
fs_rir = config.simulation_config.fs;
Options = MCRoomSimOptions('SimSpec', config.simulation_config.sim_spec, ...
                          'SimDiff', config.simulation_config.sim_diff, ...
                          'Duration', config.simulation_config.duration, ...
                          'Order', config.simulation_config.order, ...
                          'Fs', fs_rir);

target_lufs = source_config.output_config.normalization_target_lufs;

% Process assigned rooms
files_generated = 0;
start_time = tic;

for room_idx = start_room:end_room
    room_config = room_configs(room_idx);
    
    fprintf('\n--- Room %d/%d (Global: %d/%d) ---\n', ...
            room_idx - start_room + 1, end_room - start_room + 1, ...
            room_idx, total_rooms);
    fprintf('    Dimensions: %.1f x %.1f x %.1f m\n', ...
            room_config.dimensions(1), room_config.dimensions(2), room_config.dimensions(3));
    fprintf('    Reverb: %s\n', room_config.reverb_id);
    
    % Generate source configurations for this room
    source_configs = generate_source_configs(source_config_file, ...
                                            room_config.center, ...
                                            room_config.dimensions);
    
    fprintf('    Processing %d source configurations...\n', length(source_configs));
    
    % Process each source configuration
    for src_idx = 1:length(source_configs)
        src_config = source_configs(src_idx);
        
        % Generate filename
        filename = generate_filename(src_config.arc_angle, ...
                                    src_config.front_sources, ...
                                    src_config.back_sources, ...
                                    room_config.dimensions, ...
                                    room_config.center, ...
                                    room_config.reverb_id, ...
                                    src_config.arc_radius, ...
                                    room_config.hrir_id);
        
        output_path = fullfile(batch_output_dir, filename);
        
        % Skip if file already exists
        if exist(output_path, 'file')
            continue;
        end
        
        % Synthesize
        try
            synthesize_single_batch(src_config.Sources, ...
                                   room_config.Receivers, ...
                                   room_config.Room, ...
                                   Options, ...
                                   src_config.audio_files, ...
                                   output_path, ...
                                   fs_rir, ...
                                   target_lufs);
            
            files_generated = files_generated + 1;
            
            % Progress update every 10 files
            if mod(files_generated, 10) == 0
                elapsed = toc(start_time);
                rate = files_generated / elapsed;
                fprintf('      [Batch %d] Generated %d files | Rate: %.1f files/min\n', ...
                        batch_id, files_generated, rate * 60);
            end
            
        catch ME
            fprintf('      ERROR: %s - %s\n', filename, ME.message);
            continue;
        end
    end
end

% Final statistics for this batch
total_time = toc(start_time);
fprintf('\n========================================\n');
fprintf('BATCH %d COMPLETE\n', batch_id);
fprintf('========================================\n');
fprintf('Files generated: %d\n', files_generated);
fprintf('Time: %.1f minutes\n', total_time / 60);
fprintf('Rate: %.1f files/minute\n', files_generated / (total_time / 60));
fprintf('Output: %s\n', batch_output_dir);
fprintf('========================================\n');

% Write completion marker
marker_file = fullfile(batch_output_dir, sprintf('BATCH_%03d_COMPLETE.txt', batch_id));
fid = fopen(marker_file, 'w');
fprintf(fid, 'Batch %d of %d\n', batch_id, total_batches);
fprintf(fid, 'Files generated: %d\n', files_generated);
fprintf(fid, 'Completed: %s\n', datestr(now));
fclose(fid);

end

function synthesize_single_batch(Sources, Receivers, Room, Options, audio_files, output_path, fs_rir, target_lufs)
% SYNTHESIZE_SINGLE_BATCH Batch version of synthesis function
% (Identical to synthesize_single but optimized for batch processing)

% Run simulation
RIR = RunMCRoomSim(Sources, Receivers, Room, Options);

num_sources = length(Sources);

% Load audio
signals = cell(num_sources, 1);
for k = 1:num_sources
    if ~exist(audio_files{k}, 'file')
        error('Audio file not found: %s', audio_files{k});
    end
    [x, fs] = audioread(audio_files{k});
    if size(x, 2) > 1, x = mean(x, 2); end
    if fs ~= fs_rir, x = resample(x, fs_rir, fs); end
    signals{k} = x;
end

% Match lengths
minLen = min(cellfun(@length, signals));
for k = 1:num_sources
    signals{k} = signals{k}(1:minLen);
end

% Calculate output size
max_rir_len = max(cellfun(@(x) length(x), RIR(:)));
output_len = minLen + max_rir_len - 1;

% Process
yL = zeros(output_len, 1);
yR = zeros(output_len, 1);

for k = 1:num_sources
    yL_temp = fftfilt(RIR{1, k}, signals{k});
    yR_temp = fftfilt(RIR{2, k}, signals{k});
    yL(1:length(yL_temp)) = yL(1:length(yL_temp)) + yL_temp;
    yR(1:length(yR_temp)) = yR(1:length(yR_temp)) + yR_temp;
end

% Normalize and save
y_stereo = normalize_loudness([yL, yR], fs_rir, target_lufs);
audiowrite(output_path, y_stereo, fs_rir);

end
