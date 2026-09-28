%% Audio dataset preprocessing
%
% Windows / MATLAB
%
% Processing:
%
%   1. Recursively find WAV/FLAC
%   2. Reject files with bit depth < 16
%   3. Reject files containing only silence
%
%   A. After filtering, reject/abort if any surviving file has >= 3 channels
%
%   4. Count surviving files
%   5. Trim leading/trailing silence
%
%   B. If stereo, downmix to mono
%
%   6. Resample to 48 kHz
%   7. Repeat audio until >= 10 seconds
%
%   C. Trim tail so output is EXACTLY 10 seconds
%
%   8. Normalize to -14 LUFS
%   9. Normalize absolute peak to 0.9
%  10. Randomly distribute into folders, 6 files/folder
%
% IMPORTANT:
% Only one complete audio file is loaded at a time during processing.
%
% The initial filtering pass reads audio in chunks.

clear;
clc;

%% ================= USER SETTINGS =================

inputRoot = 'D:\KW\corpuses\ALL_MUSIC';
outputRoot = 'D:\KW\ALL_MUSIC_PROCESSED';

targetFs = 48000;

% Silence threshold in dBFS.
silenceThresholdDb = -50;

% RMS analysis parameters
analysisWindowSec = 0.025;       % 25 ms
analysisHopSec    = 0.010;       % 10 ms

% Minimum continuous sound duration used for detecting start/end.
minSoundDurationSec = 0.050;     % 50 ms

% Minimum audio remaining after trimming.
minAudioDurationSec = 2.50;     % 10 ms

% Crossfade between repetitions.
crossfadeSec = 0.050;             % 50 ms

% Fade at final track boundaries.
boundaryFadeSec = 0.050;          % 50 ms

% Loudness target.
targetLoudness = -14;

% Absolute peak target.
targetPeak = 0.9;

% Number of files per output folder.
filesPerFolder = 6;

% Discard incomplete final group.
discardRemainder = true;

% Output WAV bit depth.
outputBits = 24;

% ==================================================


%% =================================================
% STEP 1: FIND ALL AUDIO FILES RECURSIVELY
% ==================================================

fprintf('Searching recursively for audio files...\n');

wavFiles  = dir(fullfile(inputRoot, '**', '*.wav'));
flacFiles = dir(fullfile(inputRoot, '**', '*.flac'));

allFiles_bloated = [wavFiles; flacFiles];
% Randomly keep at most this many files
maxFiles = 2300;

if numel(allFiles_bloated) > maxFiles
    rng('shuffle');  % Different random selection each run
    keepIdx = randperm(numel(allFiles_bloated), maxFiles);
    allFiles = allFiles_bloated(keepIdx);
else 
    fprintf("Error: too few files (%d of %d) in input folders %s", numel(allFiles_bloated),maxFiles, inputRoot);
    return;
end
fprintf('Found %d audio files.\n', numel(allFiles));


%% =================================================
% STEPS 2 + 3:
% BIT DEPTH FILTER + SILENCE FILTER
% ==================================================

fprintf('\n========== FILTERING ==========\n');

validFiles = {};

numRejectedBitDepth = 0;
numRejectedSilence  = 0;
numErrors           = 0;
numRejectedMic2 = 0;

for k = 1:numel(allFiles)

    filePath = fullfile(allFiles(k).folder, allFiles(k).name);
    if contains(allFiles(k).name, 'mic2', 'IgnoreCase', true)
         numRejectedMic2 = numRejectedMic2 + 1;
        continue;
    end

    fprintf('[%d/%d] %s\n', ...
        k, numel(allFiles), filePath);

    try

        info = audioinfo(filePath);

        %% STEP 2: BIT DEPTH

        if isfield(info, 'BitsPerSample') && info.BitsPerSample < 16
              fprintf('    REJECT: bit depth = %g bits\n', bits);
        
                    numRejectedBitDepth = numRejectedBitDepth + 1;
            continue;
        end     

        %% STEP 3: SILENCE

        isSilent = fileIsSilent( ...
            filePath, ...
            info, ...
            silenceThresholdDb, ...
            analysisWindowSec, ...
            analysisHopSec);

        if isSilent

            fprintf('    REJECT: silence\n');

            numRejectedSilence = numRejectedSilence + 1;

            continue;
        end


        %% File passed filters

        validFiles{end+1} = filePath; %#ok<SAGROW>

    catch ME

        fprintf(2, ...
            '    ERROR: %s\n', ...
            ME.message);

        numErrors = numErrors + 1;
    end
end


%% =================================================
% STEP A:
% CHECK CHANNEL COUNT AFTER FILTERING
%
% Any surviving file with >= 3 channels causes
% the entire program to print the offending files
% and EXIT.
% ==================================================

fprintf('\n========== CHANNEL CHECK ==========\n');

multichannelFiles = {};

for k = 1:numel(validFiles)

    filePath = validFiles{k};

    try

        info = audioinfo(filePath);

        if info.NumChannels >= 3

            multichannelFiles{end+1} = filePath; %#ok<SAGROW>

        end

    catch ME

        fprintf(2, ...
            'Could not inspect channels: %s\n', ...
            filePath);

        fprintf(2, ...
            '%s\n', ...
            ME.message);

        error('Aborting because channel information could not be verified.');
    end
end


%% Abort if any 3+ channel tracks were found

if ~isempty(multichannelFiles)

    fprintf(2, '\n');
    fprintf(2, '========================================\n');
    fprintf(2, 'ERROR: MULTICHANNEL TRACKS FOUND\n');
    fprintf(2, 'Tracks with 3 or more channels:\n');
    fprintf(2, '========================================\n');

    for k = 1:numel(multichannelFiles)

        filePath = multichannelFiles{k};

        info = audioinfo(filePath);

        fprintf(2, ...
            '[%d] %d channels\n', ...
            k, ...
            info.NumChannels);

        fprintf(2, ...
            '    Folder: %s\n', ...
            info.Filename);

        fprintf(2, ...
            '    File:   %s\n\n', ...
            filePath);
    end

    fprintf(2, ...
        'No files were processed.\n');

    fprintf(2, ...
        'Program terminated.\n');

    return;
end


%% =================================================
% STEP 4:
% COUNT VALID FILES
% ==================================================

C = numel(validFiles);

fprintf('\n========== FILTER RESULT ==========\n');

fprintf('Original files:       %d\n', numel(allFiles));
fprintf('Rejected bit depth:   %d\n', numRejectedBitDepth);
fprintf('Rejected silence:     %d\n', numRejectedSilence);
fprintf('Errors:               %d\n', numErrors);
fprintf('Rejected mic2 (potential leaks):        %d\n', numRejectedMic2);
fprintf('Valid files C:        %d\n', C);


%% =================================================
% DETERMINE OUTPUT FOLDER COUNT
% ==================================================

if discardRemainder

    numFolders = floor(C / filesPerFolder);

    numFilesToProcess = ...
        numFolders * filesPerFolder;

else

    numFolders = ceil(C / filesPerFolder);

    numFilesToProcess = C;

end


fprintf('Output folders:       %d\n', numFolders);
fprintf('Files to process:     %d\n', numFilesToProcess);
fprintf('Files discarded:      %d\n', ...
    C - numFilesToProcess);


if numFolders == 0

    fprintf(2, ...
        '\nFewer than %d valid files. Nothing to output.\n', ...
        filesPerFolder);

    return;

end


%% =================================================
% RANDOMIZE FILE ORDER
% ==================================================

rng('shuffle');

randomOrder = randperm(C);

randomOrder = ...
    randomOrder(1:numFilesToProcess);


%% =================================================
% CREATE OUTPUT FOLDERS
% ==================================================

if ~exist(outputRoot, 'dir')
    mkdir(outputRoot);
end

for folderIdx = 1:numFolders

    folderPath = fullfile( ...
        outputRoot, ...
        sprintf('SPEECH_set_%03d', folderIdx));
end


%% =================================================
% PROCESS FILES
% ==================================================

fprintf('\n========== PROCESSING ==========\n');

processedCount = 0;      % total files successfully processed
folderIdx      = 0;      % only incremented when a folder is actually written
buffer         = {};     % holds {audio, fs, outputName} for the current batch

for n = 1:numFilesToProcess

    sourceIndex = randomOrder(n);
    sourcePath  = validFiles{sourceIndex};

    fprintf('\n[%d/%d]\n', n, numFilesToProcess);
    fprintf('Input:  %s\n', sourcePath);

    try
        [audio, fs] = audioread(sourcePath);
        audio = double(audio);

        [audio, startSample, endSample] = ...
            trimSilence(audio, fs, silenceThresholdDb, ...
                analysisWindowSec, analysisHopSec, minSoundDurationSec);

        fprintf('Trimmed samples: %d -> %d\n', startSample, endSample);
        duration = size(audio,1) / fs;
        fprintf('Trimmed duration: %.3f sec\n', duration);

        if duration < minAudioDurationSec
            warning('Audio became too short after trimming. Skipping.');
            clear audio;
            continue;
        end

        %% -----------------------------------------
        % STEP B:
        % STEREO -> MONO
        %
        % Only 2-channel files are downmixed.
        % Mono remains unchanged.
        % 3+ channel files have already caused
        % program termination above.
        % ------------------------------------------

        if size(audio,2) == 2

            fprintf('Downmixing stereo -> mono\n');

            audio = mean(audio, 2);

        elseif size(audio,2) == 1

            % Already mono.

        else

            % This should be impossible because of Step A,
            % but keep a safety check here.

            error( ...
                'Unexpected channel count: %d', ...
                size(audio,2));
        end


        %% -----------------------------------------
        % STEP 6:
        % RESAMPLE TO 48 kHz
        % ------------------------------------------

        if fs ~= targetFs

            fprintf( ...
                'Resampling %d -> %d Hz\n', ...
                fs, targetFs);

            audio = resample( ...
                audio, ...
                targetFs, ...
                fs);

            fs = targetFs;
        end


        %% -----------------------------------------
        % STEP 7:
        % REPEAT UNTIL >= 10 SECONDS
        % ------------------------------------------

        audio = repeatUntilTenSeconds( ...
            audio, ...
            fs, ...
            crossfadeSec);

        fprintf( ...
            'Duration after repetition: %.6f sec\n', ...
            size(audio,1) / fs);


        %% -----------------------------------------
        % STEP C:
        % EXACTLY 10 SECONDS
        %
        % Because fs = 48000, exactly 10 sec is
        % exactly 480000 samples.
        % ------------------------------------------

        targetSamples = 10 * fs;

        if size(audio,1) > targetSamples

            audio = ...
                audio(1:targetSamples, :);

        elseif size(audio,1) < targetSamples

            % This should not happen because
            % repeatUntilTenSeconds guarantees >= 10 sec,
            % but protect against numerical/implementation
            % issues.

            error( ...
                'Audio unexpectedly shorter than 10 seconds.');
        end


        fprintf( ...
            'Final duration before loudness: %.6f sec\n', ...
            size(audio,1) / fs);


        %% -----------------------------------------
        % BOUNDARY FADES
        %
        % Applied AFTER exact 10-second trimming so
        % the output remains exactly 10 seconds.
        % ------------------------------------------

        audio = applyBoundaryFades( ...
            audio, ...
            fs, ...
            boundaryFadeSec);


        %% -----------------------------------------
        % STEP 8:
        % NORMALIZE TO -14 LUFS
        % ------------------------------------------

        fprintf( ...
            'Normalizing loudness to %.1f LUFS...\n', ...
            targetLoudness);

        audio = normalize_loudness( ...
            audio, ...
            fs, ...
            targetLoudness);


        %% -----------------------------------------
        % STEP 9:
        % NORMALIZE ABSOLUTE PEAK TO 0.9
        % ------------------------------------------

        currentPeak = ...
            max(abs(audio), [], 'all');

        if currentPeak > 0

            audio = ...
                audio .* (targetPeak / currentPeak);

        end

        finalPeak = ...
            max(abs(audio), [], 'all');

        fprintf( ...
            'Final absolute peak: %.6f\n', ...
            finalPeak);


        %% -----------------------------------------
        % WRITE WAV
        % ------------------------------------------

         [~, baseName, ~] = fileparts(sourcePath);
        outputName = sprintf('%s_processed.wav', baseName);

        processedCount = processedCount + 1;
        buffer{end+1} = struct('audio', audio, 'fs', fs, 'name', outputName); %#ok<SAGROW>

        fprintf('Buffered (%d/%d for this folder)\n', numel(buffer), filesPerFolder);

        clear audio;

        %% Flush buffer once it's full
        if numel(buffer) == filesPerFolder
            folderIdx = folderIdx + 1;
            outputFolder = fullfile(outputRoot, sprintf('set_%03d', folderIdx));
            if ~exist(outputFolder, 'dir')
                mkdir(outputFolder);
            end

            for k = 1:numel(buffer)
                outputPath = fullfile(outputFolder, buffer{k}.name);
                audiowrite(outputPath, buffer{k}.audio, buffer{k}.fs, ...
                    'BitsPerSample', outputBits);
                fprintf('WROTE: %s\n', outputPath);
            end

            buffer = {};  % reset for next folder
        end

    catch ME
        fprintf(2, 'FAILED: %s\n', ME.message);
        clear audio;
    end
end

%% =================================================
% FINISHED
% ==================================================

fprintf('\n========== COMPLETE ==========\n');

fprintf( ...
    'Created %d folders.\n', ...
    numFolders);

fprintf( ...
    'Processed %d files.\n', ...
    numFilesToProcess);

fprintf( ...
    'Discarded %d valid files due to incomplete final group.\n', ...
    C - numFilesToProcess);


%% ============================================================
% LOCAL FUNCTIONS
%% ============================================================


function isSilent = fileIsSilent( ...
    filePath, ...
    info, ...
    thresholdDb, ...
    windowSec, ...
    hopSec)

    fs = info.SampleRate;

    totalSamples = info.TotalSamples;

    windowSamples = ...
        max(1, round(windowSec * fs));

    hopSamples = ...
        max(1, round(hopSec * fs));

    thresholdLinear = ...
        10^(thresholdDb / 20);


    % Read 10 seconds at a time.
    % Therefore the entire source file is never loaded.

    chunkSamples = ...
        round(10 * fs);

    pos = 1;


    while pos <= totalSamples

        endPos = ...
            min(pos + chunkSamples - 1, totalSamples);


        [x, ~] = audioread( ...
            filePath, ...
            [pos endPos]);


        x = double(x);


        % Calculate RMS across channels.
        %
        % This is equivalent to first forming a mono
        % energy representation without actually
        % changing the source signal.

        monoEnergy = ...
            sqrt(mean(x.^2, 2));


        if isempty(monoEnergy)

            pos = endPos + 1;

            continue;
        end


        for s = 1:hopSamples: ...
                (length(monoEnergy) - windowSamples + 1)

            segment = ...
                monoEnergy(s:s+windowSamples-1);


            rmsValue = ...
                sqrt(mean(segment.^2));


            if rmsValue > thresholdLinear

                isSilent = false;

                return;
            end
        end


        clear x monoEnergy;

        pos = endPos + 1;
    end


    isSilent = true;
end



function [trimmed, firstSample, lastSample] = ...
    trimSilence( ...
        audio, ...
        fs, ...
        thresholdDb, ...
        windowSec, ...
        hopSec, ...
        minSoundSec)


    n = size(audio,1);


    windowSamples = ...
        max(1, round(windowSec * fs));

    hopSamples = ...
        max(1, round(hopSec * fs));


    thresholdLinear = ...
        10^(thresholdDb / 20);


    %% Energy representation

    monoEnergy = ...
        sqrt(mean(audio.^2, 2));


    numWindows = ...
        floor((n - windowSamples) / hopSamples) + 1;


    if numWindows <= 0

        trimmed = audio;

        firstSample = 1;

        lastSample = n;

        return;
    end


    active = false(numWindows,1);


    %% Determine active windows

    for k = 1:numWindows

        idx1 = ...
            (k-1)*hopSamples + 1;

        idx2 = ...
            idx1 + windowSamples - 1;


        segment = ...
            monoEnergy(idx1:idx2);


        rmsValue = ...
            sqrt(mean(segment.^2));


        active(k) = ...
            rmsValue > thresholdLinear;
    end


    %% Require continuous sound

    requiredWindows = ...
        max(1, ceil(minSoundSec / hopSec));


    activeStable = ...
        false(size(active));


    runLength = 0;


    for k = 1:numel(active)

        if active(k)

            runLength = runLength + 1;

        else

            runLength = 0;

        end


        if runLength >= requiredWindows

            activeStable( ...
                k-requiredWindows+1:k) = true;

        end
    end


    activeIndices = ...
        find(activeStable);


    if isempty(activeIndices)

        trimmed = audio;

        firstSample = 1;

        lastSample = n;

        return;
    end


    firstWindow = ...
        activeIndices(1);

    lastWindow = ...
        activeIndices(end);


    firstSample = ...
        (firstWindow-1)*hopSamples + 1;


    lastSample = ...
        min( ...
            (lastWindow-1)*hopSamples + ...
            windowSamples, ...
            n);


    trimmed = ...
        audio(firstSample:lastSample, :);

end



function audioOut = ...
    repeatUntilTenSeconds( ...
        audio, ...
        fs, ...
        crossfadeSec)


    targetSamples = ...
        10 * fs;


    crossfadeSamples = ...
        round(crossfadeSec * fs);


    originalLength = ...
        size(audio,1);


    %% Already >= 10 sec

    if originalLength >= targetSamples

        audioOut = audio;

        return;
    end


    %% Start with empty output

    audioOut = ...
        zeros(0, size(audio,2));


    %% Keep appending until >= 10 sec

    while size(audioOut,1) < targetSamples


        if isempty(audioOut)

            audioOut = audio;

            continue;
        end


        %% Crossfade

        cf = min([ ...
            crossfadeSamples, ...
            size(audioOut,1), ...
            size(audio,1)]);


        if cf > 0

            fadeOut = ...
                linspace(1, 0, cf)';

            fadeIn = ...
                linspace(0, 1, cf)';


            oldTail = ...
                audioOut(end-cf+1:end, :);

            newHead = ...
                audio(1:cf, :);


            cross = ...
                oldTail .* fadeOut + ...
                newHead .* fadeIn;


            audioOut = [ ...
                audioOut(1:end-cf,:); ...
                cross; ...
                audio(cf+1:end,:)];

        else

            audioOut = ...
                [audioOut; audio];

        end
    end
end



function audio = ...
    applyBoundaryFades( ...
        audio, ...
        fs, ...
        fadeSec)


    n = size(audio,1);


    fadeSamples = ...
        min( ...
            round(fadeSec * fs), ...
            floor(n/2));


    if fadeSamples <= 0
        return;
    end


    fadeIn = ...
        linspace(0, 1, fadeSamples)';


    fadeOut = ...
        linspace(1, 0, fadeSamples)';


    audio(1:fadeSamples,:) = ...
        audio(1:fadeSamples,:) .* fadeIn;


    audio(end-fadeSamples+1:end,:) = ...
        audio(end-fadeSamples+1:end,:) .* fadeOut;

end



function sig = ...
    normalize_loudness( ...
        sig, ...
        fs, ...
        targetLoudness)


    % Gain-only LUFS normalization.
    %
    % This intentionally does NOT use a limiter because
    % the next step explicitly normalizes peak to 0.9
    % and you said that changing LUFS at that point
    % is acceptable.


    loudness = ...
        integratedLoudness(sig, fs);


    if ~isfinite(loudness)

        warning( ...
            'Could not calculate integrated LUFS.');

        return;
    end


    gain = ...
        10^((targetLoudness - loudness) / 20);


    sig = ...
        sig .* gain;

end