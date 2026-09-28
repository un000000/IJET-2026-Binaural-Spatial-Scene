function [source_configs] = generate_source_configs(config_file, room_center, ~, num_sources)
% GENERATE_SOURCE_CONFIGS  Generate source positions for all arc combinations.
%
% Changes from previous version:
%   - num_sources_options is IGNORED; caller passes the actual count.
%   - arc_radius loop removed (single radius from config is used directly).
%   - front_and_back splits floor(num_sources/2) per arc (no noise slot).
%   - front_only / back_only use all num_sources on the single arc.
%   - front_sources / back_sources fields retained for backward compat
%     but are now just informational counts, not character arrays.
%
% Inputs:
%   config_file  - path to JSON configuration file
%   room_center  - [x, y, z]
%   ~            - (room_dims, unused — kept for call-site compatibility)
%   num_sources  - actual number of song sources for this folder
%
% Output struct fields:
%   .Sources       - MCRoomSim Sources array
%   .arc_mode      - 'front_only' | 'back_only' | 'front_and_back'
%   .arc_angle     - spread angle (degrees)
%   .arc_radius    - radius (metres)
%   .num_sources   - total source count passed in
%   .front_sources - number of sources on front arc
%   .back_sources  - number of sources on back arc

config        = jsondecode(fileread(config_file));
arc_radius    = config.source_config.arc_radii(1);   % single radius
%arc_radius    = room_center(1)-1.5;
arc_angles    = config.source_config.arc_angles(:)';
source_height = config.source_config.height;
arc_modes     = config.arc_configurations.modes;

total_configs = length(arc_angles) * length(arc_modes);
fprintf('Generating source configurations (%d angles x %d modes = %d total)...\n', ...
        length(arc_angles), length(arc_modes), total_configs);

source_configs = struct('Sources', {}, 'arc_mode', {}, 'arc_angle', {}, ...
                        'arc_radius', {}, 'num_sources', {}, ...
                        'front_sources', {}, 'back_sources', {});
config_idx = 1;

for angle_idx = 1:length(arc_angles)
    arc_angle = arc_angles(angle_idx);

    for mode_idx = 1:length(arc_modes)
        arc_mode = arc_modes{mode_idx};

        % ------------------------------------------------------------------
        % Decide per-arc source counts
        % ------------------------------------------------------------------
        dry_dont_use_noise = 1;
        noise_compliment = 1;
        if dry_dont_use_noise == 1
            noise_compliment = 0;
        end
        if strcmp(arc_mode, 'FF')
            % Use ALL song sources + 1 noise
            total_sources = num_sources + noise_compliment;
        
            % Split as evenly as possible (keeps the odd one)
            n_front = ceil(total_sources / 2);
            n_back  = floor(total_sources / 2);
        
        elseif strcmp(arc_mode, 'FB')
            % All sources (songs + noise) in front
            n_front = num_sources + noise_compliment;
            n_back  = 0;
        
        elseif strcmp(arc_mode, 'BF')  % BF
            % All sources (songs + noise) in back
            n_front = 0;
            n_back  = num_sources + noise_compliment;
        elseif strcmp(arc_mode, 'BB')
            % Use ALL song sources + 1 noise
            total_sources = num_sources + noise_compliment;
        
            % Split as evenly as possible (keeps the odd one)
            n_front = ceil(total_sources / 2);
            n_back  = floor(total_sources / 2);
        end

        Sources = [];

        % --- FRONT ARC ----------------------------------------------------
        if n_front > 0
            front_pos = arc_positions(room_center, arc_radius, arc_angle, ...
                                      n_front, source_height, 'front');
            for k = 1:n_front
                direction = room_center - front_pos{k};
                azimuth   = atan2d(direction(2), direction(1));
                Sources   = AddSource(Sources, ...
                    'Type',        'cardioid', ...
                    'Location',    front_pos{k}, ...
                    'Orientation', [azimuth, 0, 0]);
            end
        end

        % --- BACK ARC -----------------------------------------------------
        if n_back > 0
            back_pos = arc_positions(room_center, arc_radius, arc_angle, ...
                                     n_back, source_height, 'back');
            for k = 1:n_back
                direction = room_center - back_pos{k};
                azimuth   = atan2d(direction(2), direction(1));
                Sources   = AddSource(Sources, ...
                    'Type',        'cardioid', ...
                    'Location',    back_pos{k}, ...
                    'Orientation', [azimuth, 0, 0]);
            end
        end

        source_configs(config_idx).Sources       = Sources;
        source_configs(config_idx).arc_mode      = arc_mode;
        source_configs(config_idx).arc_angle     = arc_angle;
        source_configs(config_idx).arc_radius    = arc_radius;
        source_configs(config_idx).num_sources   = num_sources;
        source_configs(config_idx).front_sources = n_front;
        source_configs(config_idx).back_sources  = n_back;

        config_idx = config_idx + 1;
    end
end

fprintf('Generated %d source configurations successfully.\n', length(source_configs));
end


% =========================================================================
function positions = arc_positions(room_center, radius, arc_angle, N, height, side)
% ARC_POSITIONS  Return N evenly-spaced positions along a front or back arc.
%
% side = 'front' → arc centre is at room_center + radius in +y
% side = 'back'  → arc centre is at room_center - radius in -y

positions = cell(N, 1);
if N == 0, return; end

if strcmp(side, 'front')
    arc_cy = room_center(2) + radius;
    sign_y = -1;   % arc bows away from listener (+y side)
else
    arc_cy = room_center(2) - radius;
    sign_y = +1;
end

if N == 1 || arc_angle == 0
    positions{1} = [room_center(1), arc_cy, height];
    return;
end

angles_deg = linspace(-arc_angle/2, arc_angle/2, N);

for i = 1:N
    theta        = deg2rad(angles_deg(i));
    x            = room_center(1) + radius * sin(theta);
    y            = arc_cy + sign_y * radius * (1 - cos(theta));
    positions{i} = [x, y, height];
end
end