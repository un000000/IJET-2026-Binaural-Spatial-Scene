% =========================================================================
function filename = generate_filename(folder_name, institute, hrtf_id, arc_angle, mode, room_idx)
% GENERATE_FILENAME  Output format:
%   <folder-name>###<institute>_<hrtfID>_<arcAngle>_<roomID>_<mode>.wav
% Underscores in the folder name are converted to hyphens so that the
% "###" prefix and the "_"-separated metadata stay unambiguous.
folder_clean = strrep(folder_name, '_', '-');
filename = sprintf('%s###%s_hrtf%s_%03d_%02d_%s.wav', ...
                   folder_clean, institute, hrtf_id, arc_angle, room_idx, mode);
end
