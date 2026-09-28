# Setup Guide - 3D Audio Synthesis System

## Prerequisites

### Required Software

1. **MATLAB** (R2019b or later recommended)
   - Base MATLAB installation
   - Signal Processing Toolbox (for filtering, resampling)
   
2. **Optional MATLAB Toolboxes**:
   - Audio Toolbox (for EBU R128 loudness normalization)
   - Parallel Computing Toolbox (for local parallel processing)
   
3. **MCROOMSIM**
   - Download from: http://www.mcroomsimnew.sourceforge.net/
   - Version 2.12 or later
   - Extract and add to MATLAB path

### System Requirements

**Minimum**:
- 8 GB RAM
- 100 GB free disk space
- Multi-core CPU

**Recommended**:
- 16+ GB RAM
- 500+ GB free disk space (for full dataset)
- 8+ core CPU or cluster access
- SSD for faster I/O

## Installation Steps

### 1. Download MCROOMSIM

```bash
# Download and extract MCROOMSIM
wget http://sourceforge.net/projects/mcroomsim/files/MCRoomSim_v2.12.zip
unzip MCRoomSim_v2.12.zip -d MCRoomSim/
```

### 2. Set Up Directory Structure

```bash
# Create project directory
mkdir -p 3d_audio_synthesis
cd 3d_audio_synthesis

# Create subdirectories
mkdir -p audio_sources      # Put source audio files here
mkdir -p generated_audio    # Output directory
mkdir -p logs               # For batch job logs
```

### 3. Copy Project Files

Copy all `.m` files and `.json` config files to the project directory:

```
3d_audio_synthesis/
├── config_rooms.json
├── config_sources.json
├── generate_room_configs.m
├── generate_source_configs.m
├── generate_filename.m
├── normalize_loudness.m
├── synthesize_all_audio.m
├── batch_synthesize.m
├── merge_batch_results.m
├── prepare_audio_sources.m
├── example_usage.m
├── run_batch_slurm.sh
├── README.md
├── audio_sources/          (create this)
│   ├── source1.wav
│   ├── source2.wav
│   └── ...
└── generated_audio/        (will be created)
```

### 4. Configure MATLAB Path

In MATLAB:

```matlab
% Add MCROOMSIM to path
addpath('/path/to/MCRoomSim/');

% Add project directory
addpath('/path/to/3d_audio_synthesis/');

% Save path
savepath;
```

Or create a startup script `setup_paths.m`:

```matlab
% setup_paths.m
function setup_paths()
    % Add MCROOMSIM
    addpath('/path/to/MCRoomSim/');
    
    % Add project files
    addpath(pwd);
    
    fprintf('Paths configured for 3D Audio Synthesis\n');
end
```

### 5. Prepare Audio Source Files

#### Option A: Use Your Own Audio Files

```matlab
% Convert your audio files to required format
prepare_audio_sources('./my_audio_files/', './audio_sources/', 20);
```

#### Option B: Download Sample Datasets

**LibriSpeech (Speech)**:
```bash
# Download dev-clean (small subset for testing)
wget https://www.openslr.org/resources/12/dev-clean.tar.gz
tar -xzf dev-clean.tar.gz

# Extract 20 random speech files
# (You'll need to write a script to copy/rename these)
```

**ESC-50 (Environmental Sounds)**:
```bash
# Download from GitHub
git clone https://github.com/karolpiczak/ESC-50.git
# Audio files are in ESC-50/audio/
```

**MUSAN (Music, Speech, Noise)**:
```bash
# Download music subset
wget https://www.openslr.org/resources/17/musan.tar.gz
tar -xzf musan.tar.gz
# Music files are in musan/music/
```

After downloading, use `prepare_audio_sources.m` to convert them.

### 6. Edit Configuration Files

#### Adjust Room Dimensions (config_rooms.json)

For faster testing, reduce the number of room sizes:

```json
{
  "room_dimensions": {
    "sizes": [
      [5.0, 5.0, 2.5],
      [6.0, 6.0, 3.0]
    ]
  }
}
```

#### Adjust Source Configuration (config_sources.json)

For testing, use fewer options:

```json
{
  "source_config": {
    "arc_radii": [1.5, 2.0],
    "arc_angles": [0, 30, 60],
    "num_sources_options": [4, 6]
  }
}
```

## Verification

### Test Installation

```matlab
% Run example usage script
run example_usage.m
```

This will:
- Load configurations
- Display statistics
- Estimate total files
- Generate a small test batch

### Test MCROOMSIM

```matlab
% Simple MCROOMSIM test
Sources = AddSource([], 'Type', 'omnidirectional', 'Location', [1,1,1.5]);
Receivers = AddReceiver([], 'Type', 'omnidirectional', 'Location', [2,2,1.5]);
Room = SetupRoom('Dim', [5,5,2.5], 'Freq', [125,250,500,1000,2000,4000], ...
                 'Absorption', repmat([0.1], 6, 6), 'Scattering', repmat([0.5], 6, 6));
Options = MCRoomSimOptions('Fs', 48000);

RIR = RunMCRoomSim(Sources, Receivers, Room, Options);

if ~isempty(RIR)
    fprintf('MCROOMSIM is working correctly!\n');
else
    error('MCROOMSIM test failed!');
end
```

### Generate Test Files

```matlab
% Generate 10 test files
synthesize_all_audio('config_rooms.json', 'config_sources.json', ...
                     './test_output/', 1, 10);
```

Check output:
- Files should be in `./test_output/`
- Filenames should follow the naming convention
- Listen to verify spatialization

## Common Issues and Solutions

### Issue 1: "MCROOMSIM not found"

**Solution**: Add MCROOMSIM to MATLAB path
```matlab
addpath('/path/to/MCRoomSim/');
savepath;
```

### Issue 2: "Audio file not found"

**Solution**: Ensure audio files exist with correct naming
```bash
ls audio_sources/
# Should show: source1.wav, source2.wav, etc.
```

Use `prepare_audio_sources.m` to convert and rename files.

### Issue 3: Out of memory

**Solution**: Process in smaller batches
```matlab
% Instead of all at once
synthesize_all_audio('config_rooms.json', 'config_sources.json');

% Process in batches
batch_synthesize('config_rooms.json', 'config_sources.json', 1, 10);
batch_synthesize('config_rooms.json', 'config_sources.json', 2, 10);
% etc.
```

### Issue 4: Very slow generation

**Solutions**:
1. Use SSD for faster I/O
2. Reduce diffuse ray count in room settings
3. Use parallel processing
4. Use cluster/cloud computing

### Issue 5: Files sound wrong

**Checks**:
```matlab
% Verify a generated file
[y, fs] = audioread('./generated_audio/30_ac00000000_0000000000_050_050_025_025_025_017_a.wav');

% Check sample rate
fprintf('Sample rate: %d Hz\n', fs);  % Should be 48000

% Check channels
fprintf('Channels: %d\n', size(y, 2));  % Should be 2 (stereo)

% Check for clipping
fprintf('Peak level: %.2f dBFS\n', 20*log10(max(abs(y(:)))));  % Should be < 0

% Check left/right difference (should be different for spatial audio)
correlation = corr(y(:,1), y(:,2));
fprintf('L/R correlation: %.3f\n', correlation);  % Should be < 1.0
```

## Performance Optimization

### Local Machine (Single Core)

For testing or small batches:
```matlab
synthesize_all_audio('config_rooms.json', 'config_sources.json', ...
                     './output/', 5, 20);
```

### Local Machine (Parallel)

Using MATLAB Parallel Computing Toolbox:
```matlab
parfor batch_id = 1:8  % 8 parallel workers
    batch_synthesize('config_rooms.json', 'config_sources.json', ...
                     batch_id, 8);
end

% Merge results
merge_batch_results('./generated_audio/', 8);
```

### HPC Cluster (SLURM)

Submit array job:
```bash
# Edit run_batch_slurm.sh first (adjust paths, resources)
sbatch run_batch_slurm.sh

# Monitor jobs
squeue -u $USER

# Check progress
tail -f logs/batch_1.out
```

After completion:
```matlab
merge_batch_results('./generated_audio/', 10);
```

### Cloud Computing (AWS/GCP)

1. Launch multiple instances
2. Install MATLAB and dependencies on each
3. Assign different batch IDs to each instance
4. Download results and merge

## Next Steps

1. **Start Small**: Generate 10-100 files first to verify everything works
2. **Validate Output**: Listen to files, check spatialization
3. **Scale Up**: Once validated, run full generation
4. **Monitor Progress**: Check logs, disk space
5. **Backup**: Regularly backup generated files

## Getting Help

- Check README.md for detailed documentation
- Run `example_usage.m` for working examples
- Examine individual function help: `help generate_room_configs`
- MCROOMSIM documentation: http://sourceforge.net/projects/mcroomsim/

## Disk Space Planning

Estimate required space:

```matlab
% Run this to estimate
run example_usage.m  % See "ESTIMATING TOTAL FILES" section

% Rule of thumb:
% - Each file: 2-10 MB (depends on source duration, room size)
% - 10,000 files ≈ 50-100 GB
% - 100,000 files ≈ 500 GB - 1 TB
```

Always have 20-30% extra space as buffer.
