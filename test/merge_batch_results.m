function merge_batch_results(output_dir, total_batches)
% MERGE_BATCH_RESULTS Merge and verify results from parallel batch processing
%
% This function:
% - Checks completion status of all batches
% - Moves files from batch subdirectories to main output directory
% - Generates summary statistics
% - Identifies any missing or failed batches
%
% Inputs:
%   output_dir - main output directory containing batch_XXX subdirectories
%   total_batches - expected number of batches
%
% Example:
%   merge_batch_results('./generated_audio/', 10);

fprintf('========================================\n');
fprintf('MERGING BATCH RESULTS\n');
fprintf('========================================\n');

% Check if output directory exists
if ~exist(output_dir, 'dir')
    error('Output directory not found: %s', output_dir);
end

% Check completion status of each batch
fprintf('\nChecking batch completion status...\n');
completed_batches = [];
incomplete_batches = [];

for batch_id = 1:total_batches
    batch_dir = fullfile(output_dir, sprintf('batch_%03d', batch_id));
    marker_file = fullfile(batch_dir, sprintf('BATCH_%03d_COMPLETE.txt', batch_id));
    
    if exist(marker_file, 'file')
        completed_batches = [completed_batches, batch_id];
        fprintf('  [✓] Batch %d: Complete\n', batch_id);
    else
        incomplete_batches = [incomplete_batches, batch_id];
        if exist(batch_dir, 'dir')
            fprintf('  [!] Batch %d: Incomplete (directory exists but no completion marker)\n', batch_id);
        else
            fprintf('  [✗] Batch %d: Not started (directory not found)\n', batch_id);
        end
    end
end

fprintf('\nSummary: %d/%d batches completed\n', ...
        length(completed_batches), total_batches);

if ~isempty(incomplete_batches)
    fprintf('WARNING: The following batches are incomplete: %s\n', ...
            mat2str(incomplete_batches));
    fprintf('You may want to re-run these batches before merging.\n');
    
    response = input('Continue with merge anyway? (y/n): ', 's');
    if ~strcmpi(response, 'y')
        fprintf('Merge cancelled.\n');
        return;
    end
end

% Count total files across all batches
fprintf('\nCounting files in each batch...\n');
total_files = 0;
batch_file_counts = zeros(1, total_batches);

for batch_id = 1:total_batches
    batch_dir = fullfile(output_dir, sprintf('batch_%03d', batch_id));
    if exist(batch_dir, 'dir')
        files = dir(fullfile(batch_dir, '*.wav'));
        batch_file_counts(batch_id) = length(files);
        total_files = total_files + length(files);
        fprintf('  Batch %d: %d files\n', batch_id, length(files));
    end
end

fprintf('\nTotal files to merge: %d\n', total_files);

% Ask for confirmation
fprintf('\nThis will move all files to: %s\n', output_dir);
response = input('Proceed with merge? (y/n): ', 's');
if ~strcmpi(response, 'y')
    fprintf('Merge cancelled.\n');
    return;
end

% Merge files
fprintf('\nMerging files...\n');
merged_count = 0;
duplicate_count = 0;
error_count = 0;

for batch_id = 1:total_batches
    batch_dir = fullfile(output_dir, sprintf('batch_%03d', batch_id));
    
    if ~exist(batch_dir, 'dir')
        continue;
    end
    
    files = dir(fullfile(batch_dir, '*.wav'));
    
    for i = 1:length(files)
        source_file = fullfile(batch_dir, files(i).name);
        dest_file = fullfile(output_dir, files(i).name);
        
        % Check if file already exists in destination
        if exist(dest_file, 'file')
            duplicate_count = duplicate_count + 1;
            
            % Compare file sizes
            source_info = dir(source_file);
            dest_info = dir(dest_file);
            
            if source_info.bytes ~= dest_info.bytes
                fprintf('  WARNING: Duplicate with different size: %s\n', files(i).name);
                fprintf('           Source: %d bytes, Dest: %d bytes\n', ...
                        source_info.bytes, dest_info.bytes);
            end
            
            % Skip (keep existing file)
            continue;
        end
        
        % Move file
        try
            movefile(source_file, dest_file);
            merged_count = merged_count + 1;
            
            if mod(merged_count, 100) == 0
                fprintf('  Merged %d/%d files...\n', merged_count, total_files);
            end
        catch ME
            error_count = error_count + 1;
            fprintf('  ERROR moving %s: %s\n', files(i).name, ME.message);
        end
    end
end

fprintf('\nMerge complete!\n');
fprintf('  Files merged: %d\n', merged_count);
fprintf('  Duplicates skipped: %d\n', duplicate_count);
fprintf('  Errors: %d\n', error_count);

% Optional: Remove empty batch directories
fprintf('\nCleaning up batch directories...\n');
for batch_id = 1:total_batches
    batch_dir = fullfile(output_dir, sprintf('batch_%03d', batch_id));
    
    if ~exist(batch_dir, 'dir')
        continue;
    end
    
    % Check if directory is empty (only completion marker remains)
    files = dir(fullfile(batch_dir, '*.wav'));
    
    if isempty(files)
        try
            rmdir(batch_dir, 's');
            fprintf('  Removed empty batch directory: batch_%03d\n', batch_id);
        catch ME
            fprintf('  Could not remove batch_%03d: %s\n', batch_id, ME.message);
        end
    else
        fprintf('  Batch_%03d still contains %d files (not removed)\n', batch_id, length(files));
    end
end

% Generate final statistics
fprintf('\n========================================\n');
fprintf('FINAL STATISTICS\n');
fprintf('========================================\n');
fprintf('Output directory: %s\n', output_dir);
fprintf('Total files: %d\n', merged_count + duplicate_count);
fprintf('New files merged: %d\n', merged_count);
fprintf('Pre-existing files: %d\n', duplicate_count);
fprintf('========================================\n');

% Save summary report
report_file = fullfile(output_dir, 'MERGE_REPORT.txt');
fid = fopen(report_file, 'w');
fprintf(fid, '3D Audio Synthesis - Merge Report\n');
fprintf(fid, '==================================\n\n');
fprintf(fid, 'Merge Date: %s\n', datestr(now));
fprintf(fid, 'Total Batches: %d\n', total_batches);
fprintf(fid, 'Completed Batches: %d\n', length(completed_batches));
fprintf(fid, 'Incomplete Batches: %d\n', length(incomplete_batches));
fprintf(fid, '\nFile Statistics:\n');
fprintf(fid, '  Total Files: %d\n', merged_count + duplicate_count);
fprintf(fid, '  Newly Merged: %d\n', merged_count);
fprintf(fid, '  Pre-existing: %d\n', duplicate_count);
fprintf(fid, '  Errors: %d\n', error_count);
fprintf(fid, '\nBatch File Counts:\n');
for batch_id = 1:total_batches
    fprintf(fid, '  Batch %d: %d files\n', batch_id, batch_file_counts(batch_id));
end
if ~isempty(incomplete_batches)
    fprintf(fid, '\nIncomplete Batches: %s\n', mat2str(incomplete_batches));
end
fclose(fid);

fprintf('\nReport saved to: %s\n', report_file);

end
