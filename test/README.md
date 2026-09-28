# 3D Audio Synthesis System for MCROOMSIM

A comprehensive MATLAB system for generating hundreds of thousands of 3D binaural audio recordings with varying room acoustics and source positions.

## Overview

This system systematically generates binaural audio recordings by combining:
- **Room variations**: Different sizes and acoustic properties
- **Source positions**: Front/back arcs with varying angles and distances
- **Reverb characteristics**: From anechoic to highly reverberant

## System Architecture

### Core Components

1. **Configuration Files** (JSON)
   - `config_rooms.json` - Room dimensions and acoustic properties
   - `config_sources.json` - Source positioning parameters

2. **Generation Functions** (MATLAB)
   - `generate_room_configs.m` - Creates room and receiver configurations
   - `generate_source_configs.m` - Creates source position arrays
   - `generate_filename.m` - Generates standardized filenames
   - `normalize_loudness.m` - Audio normalization (EBU R128)

3. **Main Synthesis Script**
   - `synthesize_all_audio.m` - Orchestrates batch generation

## Room Configurations

### Dimensions
Based on typical acoustic research, rooms range from small to large spaces:
- Small rooms: 4x4 m (meeting rooms, studios)
- Medium rooms: 5-8 m (living rooms, classrooms)
- Large rooms: 10-20 m (halls, auditoriums)

Heights: 2.3m, 2.5m, 2.7m, 3.0m, 6.0m (for large spaces)

**Research basis**: 
- ISO 3382 (room acoustics measurements)
- Common dimensions in BRIR databases (LISTEN, CIPIC, ITA-RWTH)
- Typical room sizes in architectural acoustics literature

### Reverb Profiles

Six reverb characteristics based on standardized absorption coefficients:

| ID | Profile | RT60 (approx) | Use Case |
|----|---------|---------------|----------|
| a  | Anechoic | 0.1-0.2s | Recording studios, anechoic chambers |
| b  | Living Room | 0.3-0.5s | Furnished residential spaces |
| c  | Office | 0.4-0.6s | Commercial office environments |
| d  | Classroom | 0.5-0.8s | Educational spaces |
| e  | Empty Room | 1.0-2.0s | Bare rooms, concrete spaces |
| f  | Concert Hall | 1.5-2.5s | Performance venues |

**Research basis**:
- ISO 354 absorption coefficient standards
- Sabine/Eyring reverberation time equations
- Published measurements from acoustic material databases

### Receiver Setup

- **Position**: Always at room center (horizontally), 1.7m height
- **Configuration**: Binaural (two omnidirectional, 18cm separation)
- **Basis**: Average human ear height when seated, standard head width

## Source Configurations

### Arc Geometry

Sources are positioned on arcs perpendicular to the front-back axis:

```
         ROOM (Top View)
    ________________________
    |                      |
    |   BACK ARC           |
    |     ===o===          |
    |        |             |
    |     (RECEIVER)       |
    |        |             |
    |     ===o===          |
    |   FRONT ARC          |
    |______________________|
```

### Parameters

**Arc Radii**: 1.5m, 2.0m, 2.4m from room center
- Near-field to mid-field distances
- Based on typical conversational to presentation distances

**Arc Angles**: 0°, 10°, 20°, ..., 90° (10° steps)
- 0° = single source directly front/back
- 90° = wide spatial spread

**Number of Sources**: 4, 6, 8, 10 (even numbers only)
- Allows symmetric front/back distribution
- Common in spatial audio research (e.g., VBAP, Ambisonics)

**Arc Modes**:
- `front_only` - Sources in front only
- `back_only` - Sources behind only  
- `front_and_back` - Sources split evenly

## Audio Source Files

Place audio files in `./audio_sources/` directory:
- Format: `source1.wav`, `source2.wav`, ..., `source35.wav`
- Requirements: WAV format, any sample rate (will be resampled to 48kHz)
- Recommendation: Use mono files or they will be converted to mono

### Recommended Audio Datasets

For research consistency, use established datasets:

**Speech**:
- TIMIT Corpus
- LibriSpeech
- VCTK Corpus (multiple speakers)

**Music**:
- MUSAN (music subset)
- Jamendo dataset

**Environmental Sounds**:
- ESC-50
- UrbanSound8K
- FSD50K (Freesound Dataset)

**Research Note**: Many papers use 10-20 diverse source signals. Consider including:
- 5-10 speech samples (different speakers)
- 5-10 music samples (different genres)
- 5-10 environmental sounds

## Filename Convention

Format: `angle_frontsources_backsources_xroom_yroom_zroom_xrecv_yrecv_zrecv_reverb.wav`

Example: `30_ac00000000_bf00000000_050_050_025_025_025_017_a.wav`

Breakdown:
- `30` - Arc angle (30°)
- `ac00000000` - Front arc: sources 'a' and 'c' (positions 1, 3)
- `bf00000000` - Back arc: sources 'b' and 'f' (positions 2, 6)
- `050_050_025` - Room: 5.0m x 5.0m x 2.5m
- `025_025_017` - Receiver: (2.5, 2.5, 1.7)
- `a` - Reverb profile 'a' (anechoic)

### Source Character Mapping
- a-z: Audio files 1-26
- 1-9: Audio files 27-35
- 0: No source at this position

## Usage

### Quick Test (Recommended First)

```matlab
% Generate small test batch
synthesize_all_audio('config_rooms.json', 'config_sources.json', ...
                     './test_output/', 2, 5);
% 2 room configs, 5 source configs per room = 10 files
```

### Full Generation

```matlab
% Generate all combinations (WARNING: Takes many hours!)
synthesize_all_audio('config_rooms.json', 'config_sources.json');
```

### Custom Configuration

Edit JSON files to customize:

```json
// config_rooms.json
{
  "room_dimensions": {
    "sizes": [
      [5.0, 5.0, 2.5],  // Add/remove room sizes
      [6.0, 6.0, 3.0]
    ]
  }
}

// config_sources.json
{
  "source_config": {
    "arc_angles": [0, 30, 60, 90],  // Reduce angle options
    "num_sources_options": [4, 8]   // Only 4 or 8 sources
  }
}
```

## Expected Output

### Volume Estimation

With default configuration:
- **Room configs**: 20 sizes × 6 reverbs = 120
- **Source configs per room**: 3 radii × 10 angles × 4 source counts × 3 modes = 360
- **Total files**: 120 × 360 = **43,200 files**

At 5MB per file average: ~**216 GB**

### Processing Time

Approximate rates (varies by hardware):
- Simple config: 10-15 files/minute
- Complex config: 5-10 files/minute

Estimated total time: **48-144 hours** for full generation

### Recommendations for Large Batches

1. **Use HPC/cluster**: Parallelize across multiple nodes
2. **Segment generation**: Process subsets (e.g., by room size)
3. **Monitor disk space**: Ensure adequate storage
4. **Checkpoint**: System skips existing files (resumable)

## Audio Quality

### Sampling Rate
- **48 kHz** (professional audio standard)
- Used in film, broadcast, spatial audio research

### Normalization
- **Target**: -23 LUFS (EBU R128 standard)
- **Fallback**: Peak normalization to -1 dBFS
- Prevents clipping when mixing multiple sources

### Spatial Rendering
- Binaural room impulse responses (BRIRs)
- Specular + diffuse reflections
- Frequency-dependent absorption/scattering

## Validation

### Quality Checks

Test generated files for:
1. **Spatialization**: Left/right channel differences for lateral sources
2. **Reverb**: RT60 matches expected profile
3. **No clipping**: Peak levels < 0 dBFS
4. **Consistent loudness**: LUFS within ±2 of target

### Sample Analysis Script

```matlab
% Analyze a generated file
[y, fs] = audioread('30_ac00000000_bf00000000_050_050_025_025_025_017_a_a.wav');

% Check for clipping
max_level = max(abs(y(:)));
fprintf('Peak level: %.2f dBFS\n', 20*log10(max_level));

% Measure RT60 (requires impulse response analysis)
% ...
```

## Troubleshooting

### Common Issues

**"Audio file not found"**
- Ensure source files exist in `./audio_sources/`
- Check file naming: `source1.wav`, `source2.wav`, etc.

**Out of memory**
- Reduce `max_rooms` or `max_sources_per_room` parameters
- Process in smaller batches
- Close other MATLAB processes

**Very slow generation**
- Normal for first few files (compilation overhead)
- Check CPU usage
- Consider reducing diffuse ray count in room config

**Files sound identical**
- Verify different source files are being used
- Check source position arrays (should differ)
- Verify room configurations vary

## Research Applications

This system is designed for:
- **Machine learning**: Training data for source localization, room classification
- **Psychoacoustics**: Perception studies with controlled acoustic variations
- **Audio signal processing**: Benchmark datasets for dereverberation, separation
- **Spatial audio**: Evaluation of rendering algorithms

## Citation

If using this system for research, please cite:
- MCROOMSIM: McGovern, S. (2012). Fast image-source method for impulse response generation
- Your specific room/source configurations
- Audio source datasets used

## License

[Specify license - typically matches MCROOMSIM license]

## Contact

[Your contact information or repository link]

---

## Appendix: Research References

### Room Acoustics
- ISO 3382-1:2009 - Acoustics - Measurement of room acoustic parameters
- ISO 354:2003 - Measurement of sound absorption in a reverberation room
- Kuttruff, H. (2016). Room Acoustics (6th ed.). CRC Press.

### Spatial Audio
- Begault, D. R. (1994). 3-D Sound for Virtual Reality and Multimedia. Academic Press.
- Blauert, J. (1997). Spatial Hearing: The Psychophysics of Human Sound Localization. MIT Press.

### Binaural Rendering
- Vorländer, M. (2008). Auralization: Fundamentals of Acoustics, Modelling, Simulation. Springer.
- Savioja, L., & Svensson, U. P. (2015). Overview of geometrical room acoustic modeling techniques. JASA.

### Audio Datasets
- Mesaros, A., et al. (2018). DCASE datasets and challenges. IEEE/ACM TASLP.
- Piczak, K. J. (2015). ESC: Dataset for environmental sound classification. ACM Multimedia.
