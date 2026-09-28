hrtf_path = './CIPIC_hrtf_database/';
subject_id = 'subject_003';
hrtf_file = fullfile(hrtf_path, subject_id, 'hrir_final.mat');

if ~exist(hrtf_file, 'file')
    error(['HRTF file not found:']);
end

hrtf_data = load(hrtf_file);

roomSideSize = 10;
roomCenter = roomSideSize/2;
centerToEarDistance = 0.09;

fs_rir = 44100;

% Load input audio files once
files = {
    'source1.wav'
    'source2.wav'
    'source3.wav'
};

signals = cell(3,1);

for k = 1:3
    [x, fs] = audioread(files{k});
    if size(x,2) > 1
        x = mean(x, 2);
    end
    if fs ~= fs_rir
        x = resample(x, fs_rir, fs);
    end
    signals{k} = x;
end

minLen = min(cellfun(@length, signals));
for k = 1:3
    signals{k} = signals{k}(1:minLen);
end

s1 = signals{1};
s2 = signals{2};
s3 = signals{3};

% ===== LOOP OVER ALL SOURCE POSITIONS =====
for sourcesX = 1:9
    for sourcesY = 5:5

        disp(['Processing X=', num2str(sourcesX), ...
              ' Y=', num2str(sourcesY)]);

        Sources = [];

        % Add 3 sources at same grid position
        for i = 1:3
            Sources = AddSource(Sources, ...
                'Type','cardioid', ...
                'Location',[sourcesX, sourcesY, 1.7], ...
                'Orientation',[0,0,0]);
        end

        % Direction grid
        az = [-80 -65 -55 -45:5:45 55 65 80];
        el = -45 + 5.625*((1:50)-1);
        [AZ, EL] = meshgrid(az, el);
        Direction = [AZ(:), EL(:)];

        % Receivers
        Receivers = [];

        Receivers = AddReceiver(Receivers, 'Type', 'impulse',...
            'Location', [roomCenter - centerToEarDistance, roomCenter, 1.7], ...
            'Orientation', [0,0,0], ...
            'Direction', Direction, ...
            'Fs', fs_rir, ...
            'Response', reshape(hrtf_data.hrir_l, [], size(hrtf_data.hrir_l,3)));

        Receivers = AddReceiver(Receivers, 'Type', 'impulse',...
            'Location', [roomCenter + centerToEarDistance, roomCenter, 1.7], ...
            'Orientation', [0,0,0], ...
            'Direction', Direction, ...
            'Fs', fs_rir, ...
            'Response', reshape(hrtf_data.hrir_r, [], size(hrtf_data.hrir_r,3)));

        % Room
        Room = SetupRoom('Dim',[roomSideSize, roomSideSize, 2.5], ...
            'Freq',[100,200,400,800,1600,3200,6400],...
            'Absorption',[ 0.6, 0.5, 0.4, 0.3, 0.4, 0.5, 0.6;
                           0.7, 0.6, 0.6, 0.3, 0.4, 0.6, 0.7;
                           0.6, 0.5, 0.4, 0.3, 0.4, 0.5, 0.6;
                           0.7, 0.6, 0.6, 0.3, 0.4, 0.6, 0.7;
                           0.5, 0.5, 0.5, 0.4, 0.4, 0.5, 0.6;
                           0.7, 0.7, 0.6, 0.5, 0.4, 0.6, 0.7],...
            'Scattering',[ 0.5, 0.5, 0.5, 0.5, 0.6, 0.6, 0.6;
                           0.5, 0.5, 0.5, 0.5, 0.6, 0.6, 0.6;
                           0.5, 0.5, 0.5, 0.5, 0.6, 0.6, 0.6;
                           0.5, 0.5, 0.5, 0.5, 0.6, 0.6, 0.6;
                           0.8, 0.8, 0.8, 0.8, 0.8, 0.9, 0.9;
                           0.5, 0.5, 0.5, 0.5, 0.6, 0.6, 0.6]);

        Options = MCRoomSimOptions('SimSpec', true, ...
                                    'SimDiff', true, ...
                                    'Duration', -1, ...
                                    'Order', [-1,-1,-1], ...
                                    'Fs', fs_rir);

        RIR = RunMCRoomSim(Sources,Receivers,Room,Options);

        % Convolution
        yL = fftfilt(RIR{1,1}, s1) + ...
             fftfilt(RIR{1,2}, s2) + ...
             fftfilt(RIR{1,3}, s3);

        yR = fftfilt(RIR{2,1}, s1) + ...
             fftfilt(RIR{2,2}, s2) + ...
             fftfilt(RIR{2,3}, s3);

        y_stereo = [yL yR];

        % Normalize (prevent clipping)
        y_stereo = y_stereo ./ max(abs(y_stereo(:)) + eps);

        % Save with position-based filename
        filename = sprintf('binaural_X%d_Y%d.wav', sourcesX, sourcesY);
        audiowrite(filename, y_stereo, fs_rir);

    end
end

disp('All combinations finished.');