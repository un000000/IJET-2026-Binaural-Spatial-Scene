% EXAMPLE_USAGE.m
% Example script demonstrating how to use the 3D audio synthesis system

%% SETUP
% Add paths if needed
% addpath('./');

%% OPTION 1: Quick test with limited configurations
fprintf('=== QUICK TEST MODE ===\n');
fprintf('Generating a small subset for testing...\n\n');

% Test with only 2 room configs and 5 source configs per room
synthesize_all_audio('config_rooms.json', 'config_sources.json', ...
                    './test_output/', 2, 5);

%% OPTION 2: Full generation (WARNING: This will take many hours/days!)
% fprintf('=== FULL GENERATION MODE ===\n');
% fprintf('This will generate hundreds of thousands of files!\n');
% fprintf('Make sure you have sufficient disk space and time.\n\n');
% 
% % Generate all combinations
% synthesize_all_audio('config_rooms.json', 'config_sources.json');

%% OPTION 3: Test room generation only
fprintf('\n=== TESTING ROOM GENERATION ===\n');
room_configs = generate_room_configs('config_rooms.json');
fprintf('Generated %d room configurations\n', length(room_configs));
fprintf('First room: %.1fx%.1fx%.1f, reverb: %s\n', ...
        room_configs(1).dimensions(1), ...
        room_configs(1).dimensions(2), ...
        room_configs(1).dimensions(3), ...
        room_configs(1).reverb_id);

%% OPTION 4: Test source generation only
fprintf('\n=== TESTING SOURCE GENERATION ===\n');
test_room_center = [5, 5, 1.7];
test_room_dims = [10, 10, 3];
source_configs = generate_source_configs('config_sources.json', ...
                                        test_room_center, test_room_dims);
fprintf('Generated %d source configurations\n', length(source_configs));
fprintf('First config: %d sources, angle: %d°, mode: %s\n', ...
        source_configs(1).num_sources, ...
        source_configs(1).arc_angle, ...
        source_configs(1).arc_mode);

%% OPTION 5: Test filename generation
fprintf('\n=== TESTING FILENAME GENERATION ===\n');
test_filename = generate_filename(30, 'ac00000000', 'bf00000000', ...
                                 [5.0, 5.0, 2.5], [2.5, 2.5, 1.7], 'a', 'a');
fprintf('Example filename: %s\n', test_filename);

%% Calculate expected number of files
fprintf('\n=== ESTIMATING TOTAL FILES ===\n');

% Load configs
room_cfg = jsondecode(fileread('config_rooms.json'));
source_cfg = jsondecode(fileread('config_sources.json'));

num_room_sizes = length(room_cfg.room_dimensions.sizes);
num_reverbs = length(fieldnames(room_cfg.reverb_profiles.profiles));
num_radii = length(source_cfg.source_config.arc_radii);
num_angles = length(source_cfg.source_config.arc_angles);
num_source_counts = length(source_cfg.source_config.num_sources_options);
num_arc_modes = length(source_cfg.arc_configurations.modes);

total_rooms = num_room_sizes * num_reverbs;
configs_per_room = num_radii * num_angles * num_source_counts * num_arc_modes;
total_files = total_rooms * configs_per_room;

fprintf('Room configurations: %d (sizes) x %d (reverbs) = %d\n', ...
        num_room_sizes, num_reverbs, total_rooms);
fprintf('Source configurations per room: %d (radii) x %d (angles) x %d (source counts) x %d (modes) = %d\n', ...
        num_radii, num_angles, num_source_counts, num_arc_modes, configs_per_room);
fprintf('\nTOTAL FILES TO GENERATE: %d\n', total_files);
fprintf('Estimated time (at 10 files/min): %.1f hours\n', total_files / 10 / 60);
fprintf('Estimated disk space (at 5MB/file): %.1f GB\n', total_files * 5 / 1024);
