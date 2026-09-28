%% ========================================================================
%% PART 1: Load HRTF Data
%% ========================================================================

% You need to download HRTF data first. Here I'll show how to load CIPIC format
% Download from: https://www.ece.ucdavis.edu/cipic/spatial-sound/hrtf-data/

% Path to HRTF files (change this to your actual path)
hrtf_path = './CIPIC_hrtf_database/';
subject_id = 'subject_003';  % Choose a subject (003 is KEMAR dummy head)

% Load HRTF data
% CIPIC format: HRIRs are stored in .mat files
hrtf_file = fullfile(hrtf_path, subject_id, 'hrir_final.mat');

if ~exist(hrtf_file, 'file')
    error(['HRTF file not found: ' hrtf_file ...
           '\nPlease download CIPIC database from: https://www.ece.ucdavis.edu/cipic/spatial-sound/hrtf-data/']);
end

% Load HRTF
hrtf_data = load(hrtf_file);
% CIPIC structure:
% hrir_l: left ear HRIRs [200 samples x 25 elevations x 50 azimuths]
% hrir_r: right ear HRIRs [200 samples x 25 elevations x 50 azimuths]

hrir_fs = 44100;  % CIPIC sampling rate

% Resample HRIRs to match room simulation sampling rate
fs_rir = 48000;
if hrir_fs ~= fs_rir
    hrir_l_resampled = zeros(ceil(size(hrtf_data.hrir_l, 1) * fs_rir / hrir_fs), ...
                              size(hrtf_data.hrir_l, 2), size(hrtf_data.hrir_l, 3));
    hrir_r_resampled = zeros(size(hrir_l_resampled));
    
    for elev = 1:size(hrtf_data.hrir_l, 2)
        for azim = 1:size(hrtf_data.hrir_l, 3)
            hrir_l_resampled(:, elev, azim) = resample(hrtf_data.hrir_l(:, elev, azim), fs_rir, hrir_fs);
            hrir_r_resampled(:, elev, azim) = resample(hrtf_data.hrir_r(:, elev, azim), fs_rir, hrir_fs);
        end
    end
    hrir_l = hrir_l_resampled;
    hrir_r = hrir_r_resampled;
else
    hrir_l = hrtf_data.hrir_l;
    hrir_r = hrtf_data.hrir_r;
end

% CIPIC angles
% Azimuth: -80° to +80° in 5° steps (interaural-polar coordinates)
% Elevation: -45° to +230.625° in various steps
azimuths = [-80 -65 -55 -45:5:45 55 65 80];  % 25 positions
elevations = [-45 -39.375 -33.75 -28.125 -22.5 -16.875 -11.25 -5.625 0 ...
              5.625 11.25 16.875 22.5 28.125 33.75 39.375 45 ...
              50.625 56.25 61.875 67.5 73.125 78.75 84.375 90];  % 25 positions (subset)

fprintf('Loaded HRTFs: %d samples, %d elevations, %d azimuths\n', ...
        size(hrir_l, 1), size(hrir_l, 2), size(hrir_l, 3));

%% ========================================================================
%% PART 2: Create Directional Receivers with HRTFs
%% ========================================================================

% Receiver position (head center)
head_center = [2.5, 2.5, 1.7];
ear_separation = 0.09;  % CIPIC uses 9cm between ear canal entrances

left_ear = head_center + [-ear_separation, 0, 0];
right_ear = head_center + [ear_separation, 0, 0];

% For MCROOMSIM, we need to provide directional impulse responses
% The software expects a structure with angular measurements

% Create receiver structure with HRTF data
% We'll use a subset of directions (MCROOMSIM can handle arbitrary directions)
num_directions = 72;  % Use 72 directions (5° azimuth resolution)
directions = [];

% Create measurement directions (azimuth, elevation in degrees)
for azim_deg = 0:5:355
    directions = [directions; azim_deg, 0];  % Horizontal plane for simplicity
end

% Interpolate HRTFs for these directions
% (For full implementation, you'd interpolate from CIPIC's measurement grid)

%% ========================================================================
%% SIMPLIFIED APPROACH: Use pre-processed HRTF as receiver type
%% ========================================================================

% MCROOMSIM v2.12 may have limitations with custom directional receivers
% A practical workaround: Use omnidirectional receivers and apply HRTFs in post-processing

Receivers = [];
Receivers = AddReceiver(Receivers, 'Type', 'omnidirectional', ...
    'Location', left_ear, 'Orientation', [0, 0, 0]);
Receivers = AddReceiver(Receivers, 'Type', 'omnidirectional', ...
    'Location', right_ear, 'Orientation', [0, 0, 0]);

%% ========================================================================
%% PART 3: Room Setup and Arc Configurations (Same as before)
%% ========================================================================

radius = 1.5;
num_sources = 3;

% LEFT ARC
angles_left = linspace(-60, 60, num_sources);
Sources_left = [];
for i = 1:num_sources
    theta = deg2rad(angles_left(i) + 180);
    x = head_center(1) + radius * cos(theta);
    y = head_center(2) + radius * sin(theta);
    Sources_left = AddSource(Sources_left, 'Type', 'cardioid', ...
        'Location', [x, y, 1.7], 'Orientation', [0, 0, 0]);
end

% RIGHT ARC
angles_right = linspace(-60, 60, num_sources);
Sources_right = [];
for i = 1:num_sources
    theta = deg2rad(angles_right(i));
    x = head_center(1) + radius * cos(theta);
    y = head_center(2) + radius * sin(theta);
    Sources_right = AddSource(Sources_right, 'Type', 'cardioid', ...
        'Location', [x, y, 1.7], 'Orientation', [0, 0, 0]);
end

% FRONT ARC
angles_front = linspace(-60, 60, num_sources);
Sources_front = [];
for i = 1:num_sources
    theta = deg2rad(angles_front(i) + 90);
    x = head_center(1) + radius * cos(theta);
    y = head_center(2) + radius * sin(theta);
    Sources_front = AddSource(Sources_front, 'Type', 'cardioid', ...
        'Location', [x, y, 1.7], 'Orientation', [0, 0, 0]);
end

% BACK ARC
angles_back = linspace(-60, 60, num_sources);
Sources_back = [];
for i = 1:num_sources
    theta = deg2rad(angles_back(i) - 90);
    x = head_center(1) + radius * cos(theta);
    y = head_center(2) + radius * sin(theta);
    Sources_back = AddSource(Sources_back, 'Type', 'cardioid', ...
        'Location', [x, y, 1.7], 'Orientation', [0, 0, 0]);
end

Room = SetupRoom('Dim', [5, 5, 2.5], ...
    'Freq', [100, 200, 400, 800, 1600, 3200, 6400], ...
    'Absorption', [0.6, 0.5, 0.4, 0.3, 0.4, 0.5, 0.6;
                   0.7, 0.6, 0.6, 0.3, 0.4, 0.6, 0.7;
                   0.6, 0.5, 0.4, 0.3, 0.4, 0.5, 0.6;
                   0.7, 0.6, 0.6, 0.3, 0.4, 0.6, 0.7;
                   0.5, 0.5, 0.5, 0.4, 0.4, 0.5, 0.6;
                   0.7, 0.7, 0.6, 0.5, 0.4, 0.6, 0.7], ...
    'Scattering', [0.5, 0.5, 0.5, 0.5, 0.6, 0.6, 0.6;
                   0.5, 0.5, 0.5, 0.5, 0.6, 0.6, 0.6;
                   0.5, 0.5, 0.5, 0.5, 0.6, 0.6, 0.6;
                   0.5, 0.5, 0.5, 0.5, 0.6, 0.6, 0.6;
                   0.8, 0.8, 0.8, 0.8, 0.8, 0.9, 0.9;
                   0.5, 0.5, 0.5, 0.5, 0.6, 0.6, 0.6]);

Options = MCRoomSimOptions('SimSpec', true, 'SimDiff', true, ...
    'Duration', -1, 'Order', [-1, -1, -1], 'Fs', fs_rir);

%% ========================================================================
%% PART 4: Enhanced Processing Function with HRTF Post-Processing
%% ========================================================================

function process_configuration_with_hrtf(Sources, Receivers, Room, Options, files, output_name, fs_rir, hrir_l, hrir_r, head_center)
    % Generate room RIRs
    RIR = RunMCRoomSim(Sources, Receivers, Room, Options);
    
    num_sources = length(Sources);
    
    % Load audio files
    signals = cell(num_sources, 1);
    for k = 1:num_sources
        [x, fs] = audioread(files{k});
        if size(x, 2) > 1, x = mean(x, 2); end
        if fs ~= fs_rir, x = resample(x, fs_rir, fs); end
        signals{k} = x;
    end
    
    % Match lengths
    minLen = min(cellfun(@length, signals));
    for k = 1:num_sources
        signals{k} = signals{k}(1:minLen);
    end
    
    % Calculate output length
    max_rir_len = max(cellfun(@(x) length(x), RIR(:)));
    hrir_len = size(hrir_l, 1);
    output_len = minLen + max_rir_len + hrir_len - 2;
    
    % Initialize outputs
    yL = zeros(output_len, 1);
    yR = zeros(output_len, 1);
    
    % Process each source
    for k = 1:num_sources
        % Get source position
            src_pos = Sources(k).Location;
        
        % Calculate direction from head center to source
        direction = src_pos - head_center;
        azimuth = atan2d(direction(2), direction(1));  % Azimuth in degrees
        elevation = atan2d(direction(3), sqrt(direction(1)^2 + direction(2)^2));
        
        % Find closest HRTF (simple nearest neighbor)
        % For CIPIC: azimuth range [-80, 80], elevation at 0°
        azim_idx = round((azimuth + 80) / 5) + 1;
        azim_idx = max(1, min(azim_idx, size(hrir_l, 3)));
        elev_idx = 13;  % Middle elevation (0°) for CIPIC
        
        % Get HRIRs for this direction
        hrir_left_dir = hrir_l(:, elev_idx, azim_idx);
        hrir_right_dir = hrir_r(:, elev_idx, azim_idx);
        
        % Apply room RIR first, then HRTF
        % This creates: signal -> room acoustics -> head/ear filtering
        room_response_L = fftfilt(RIR{1, k}, signals{k});
        room_response_R = fftfilt(RIR{2, k}, signals{k});
        
        % Apply HRTF to room responses
        binaural_L = fftfilt(hrir_left_dir, room_response_L);
        binaural_R = fftfilt(hrir_right_dir, room_response_R);
        
        % Accumulate
        yL(1:length(binaural_L)) = yL(1:length(binaural_L)) + binaural_L;
        yR(1:length(binaural_R)) = yR(1:length(binaural_R)) + binaural_R;
    end
    
    % Normalize
    max_val = max(abs([yL; yR]));
    if max_val > 0.99
        yL = yL * 0.99 / max_val;
        yR = yR * 0.99 / max_val;
    end
    
    % Save
    y_stereo = [yL, yR];
    audiowrite(output_name, y_stereo, fs_rir);
    fprintf('Saved with HRTF: %s (azimuth range: %.1f° to %.1f°)\n', ...
            output_name, azimuth, azimuth);
end

%% ========================================================================
%% PART 5: Process All Configurations
%% ========================================================================

files = {'source1.wav', 'source2.wav', 'source3.wav'};

process_configuration_with_hrtf(Sources_left, Receivers, Room, Options, files, ...
    'binaural_left_hrtf.wav', fs_rir, hrir_l, hrir_r, head_center);

process_configuration_with_hrtf(Sources_right, Receivers, Room, Options, files, ...
    'binaural_right_hrtf.wav', fs_rir, hrir_l, hrir_r, head_center);

process_configuration_with_hrtf(Sources_front, Receivers, Room, Options, files, ...
    'binaural_front_hrtf.wav', fs_rir, hrir_l, hrir_r, head_center);

process_configuration_with_hrtf(Sources_back, Receivers, Room, Options, files, ...
    'binaural_back_hrtf.wav', fs_rir, hrir_l, hrir_r, head_center);