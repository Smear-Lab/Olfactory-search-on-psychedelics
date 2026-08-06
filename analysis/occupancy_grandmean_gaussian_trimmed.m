%% Figure 5 plots (MATLAB)
% trimmed to the 6 plots actually used:
%   Saline occupancy map, DOI occupancy map, Raw HTR map,
%   Occupancy normalized HTR map, HTR map within trial, HTR map ITI
%
% reads csvs written by fig5_htr_occupancy.Rmd. r and matlab code are
% kept in separate files intentionally.
%
% Shared pipeline, repeated below with different inputs/color scales:
%   1. bin (x, y) samples into a 2D grid, summing a value per bin
%      (htr_count, mean_htr_rate, or mean_occupancy depending on section)
%   2. upscale that grid by `upscale`x via nearest-neighbor (imresize)
%   3. gaussian-smooth the upscaled grid (imgaussfilt) so the plotted map
%      isn't blocky at the original bin resolution
%   4. plot with imagesc, using a `cubehelix` colormap (third-party
%      perceptually-uniform colormap generator, not built into MATLAB --
%      see https://www.mathworks.com/matlabcentral/fileexchange/43700)
% All paths below (D:\...) are specific to the Windows machine this was
% written on and will need updating to run elsewhere.

%% Load data
occupancy_doi_time = readtable("D:\R data\occupancy_doi_time.csv");
saline_full = readtable("D:\R data\occupancy_saline_time.csv");

htr_bins = readtable("D:\R data\htr_binned.csv");
htr_rate = readtable("D:\R data\htr_grandmean.csv");
htr_rate_iti = readtable("D:\R data\htr_grandmean_iti.csv");
htr_rate_within = readtable("D:\R data\htr_grandmean_within.csv");

upscale = 10;  % upscaling factor used for all gaussian-smoothed maps

%% Raw HTR map
% unnormalized: total HTR count per bin, pooled across all DOI mice (see
% pipeline description above)
x_coordinates = htr_bins.x_bin;
y_coordinates = htr_bins.y_bin;

x_bins = unique(x_coordinates);
y_bins = unique(y_coordinates);

occupancy_map = zeros(length(y_bins), length(x_bins));
for i = 1:length(htr_bins.x_bin)
    x_idx = find(x_bins == htr_bins.x_bin(i));
    y_idx = find(y_bins == htr_bins.y_bin(i));
    occupancy_map(y_idx, x_idx) = occupancy_map(y_idx, x_idx) + htr_bins.htr_count(i);
end

occupancy_map_big = imresize(occupancy_map, [length(y_bins) * upscale, length(x_bins) * upscale], 'nearest');
occ_smooth = imgaussfilt(occupancy_map_big, upscale / 2, 'Padding', 'symmetric', 'FilterDomain', 'spatial');

cmap = 1-(cubehelix(256, 0.5, -1, 1.5, 1.0));

figure;
imagesc(x_bins, y_bins, occ_smooth);
set(gca, 'YDir', 'normal');
colormap(cmap)
caxis([0 110]);
colorbar
xlim([80, 1030]);
ylim([30, 600]);
xlabel('X Bin', 'FontSize', 16);
ylabel('Y Bin', 'FontSize', 16);
title('Raw HTR map', 'FontSize', 18);
xticks([]); yticks([]); set(gca, 'ytick', []);
xlabel(''); ylabel('');
set(gcf, 'Units', 'centimeters', 'Position', [10, 10, 25, 15]);
set(gca, 'Position', [0.08, 0.1, 0.8, 0.8]);
h = colorbar;
ylabel(h, 'Mean HTR/min', 'FontSize', 14, 'Rotation', -90);
set(h, 'FontSize', 12);
yticks_h = get(h, 'Ticks');
set(h, 'Ticks', [yticks_h(1), yticks_h(end)]);
set(h, 'YTickLabel', {num2str(yticks_h(1), '%.0f'), num2str(yticks_h(end), '%.0f')});

%% Occupancy normalized HTR map
% htr_rate.mean_htr_rate is already occupancy-normalized (HTR/min) and
% grand-averaged across mice upstream, in fig5_cleaned.Rmd -- this block
% just bins/smooths/plots it, same pipeline as the raw map above
x_coordinates = htr_rate.bin_x;
y_coordinates = htr_rate.bin_y;

x_bins = unique(x_coordinates);
y_bins = unique(y_coordinates);

occupancy_map = zeros(length(y_bins), length(x_bins));
for i = 1:length(htr_rate.bin_x)
    x_idx = find(x_bins == htr_rate.bin_x(i));
    y_idx = find(y_bins == htr_rate.bin_y(i));
    occupancy_map(y_idx, x_idx) = occupancy_map(y_idx, x_idx) + htr_rate.mean_htr_rate(i);
end

occupancy_map_big = imresize(occupancy_map, [length(y_bins) * upscale, length(x_bins) * upscale], 'nearest');
occ_smooth = imgaussfilt(occupancy_map_big, upscale / 2, 'Padding', 'symmetric', 'FilterDomain', 'spatial');

cmap = 1-(cubehelix(256, 0, 0.8, 1, 1.5));

figure;
imagesc(x_bins, y_bins, occ_smooth);
set(gca, 'YDir', 'normal');
colormap(cmap)
caxis([0 15]);
colorbar
xlabel('X Bin', 'FontSize', 16);
ylabel('Y Bin', 'FontSize', 16);
title('Occupancy normalized HTR map', 'FontSize', 16);
xticks([]); yticks([]); set(gca, 'ytick', []);
xlabel(''); ylabel('');
set(gcf, 'Units', 'centimeters', 'Position', [10, 10, 25, 15]);
set(gca, 'Position', [0.08, 0.1, 0.8, 0.8]);
h = colorbar;
ylabel(h, 'HTR/min', 'FontSize', 14);
set(h, 'FontSize', 12);
h.Label.Units = 'normalized';
pos = h.Label.Position;
pos(1) = 3;
h.Label.Position = pos;
ylabel(h, 'HTR/min', 'FontSize', 14, 'Rotation', -90);
yticks_h = get(h, 'Ticks');
set(h, 'Ticks', [yticks_h(1), yticks_h(end)]);
set(h, 'YTickLabel', {num2str(yticks_h(1), '%.0f'), num2str(yticks_h(end), '%.0f')});

%% HTR map ITI
% same as the occupancy-normalized map above, restricted to ITI periods
x_coordinates = htr_rate_iti.bin_x;
y_coordinates = htr_rate_iti.bin_y;

x_bins = unique(x_coordinates);
y_bins = unique(y_coordinates);

occupancy_map = zeros(length(y_bins), length(x_bins));
for i = 1:length(htr_rate_iti.bin_x)
    x_idx = find(x_bins == htr_rate_iti.bin_x(i));
    y_idx = find(y_bins == htr_rate_iti.bin_y(i));
    occupancy_map(y_idx, x_idx) = occupancy_map(y_idx, x_idx) + htr_rate_iti.mean_htr_rate(i);
end

occupancy_map_big = imresize(occupancy_map, [length(y_bins) * upscale, length(x_bins) * upscale], 'nearest');
occ_smooth = imgaussfilt(occupancy_map_big, upscale / 2, 'Padding', 'symmetric', 'FilterDomain', 'spatial');

cmap = 1-(cubehelix(256, 0, 0.8, 1, 1.5));

figure;
imagesc(x_bins, y_bins, occ_smooth);
set(gca, 'YDir', 'normal');
colormap(cmap)
caxis([0 15]);
colorbar
xlabel('X Bin', 'FontSize', 16);
ylabel('Y Bin', 'FontSize', 16);
title('HTR map during ITI', 'FontSize', 18);
xticks([]); yticks([]); set(gca, 'ytick', []);
xlabel(''); ylabel('');
set(gcf, 'Units', 'centimeters', 'Position', [10, 10, 25, 15]);
set(gca, 'Position', [0.08, 0.1, 0.8, 0.8]);
h = colorbar;
ylabel(h, 'HTR/min', 'FontSize', 14);
set(h, 'FontSize', 12);
ylabel(h, 'HTR/min', 'FontSize', 14, 'Rotation', -90);
yticks_h = get(h, 'Ticks');
set(h, 'Ticks', [yticks_h(1), yticks_h(end)]);
set(h, 'YTickLabel', {num2str(yticks_h(1), '%.0f'), num2str(yticks_h(end), '%.0f')});

%% HTR map within trial
% same as the occupancy-normalized map above, restricted to within-trial periods
x_coordinates = htr_rate_within.bin_x;
y_coordinates = htr_rate_within.bin_y;

x_bins = unique(x_coordinates);
y_bins = unique(y_coordinates);

occupancy_map = zeros(length(y_bins), length(x_bins));
for i = 1:length(htr_rate_within.bin_x)
    x_idx = find(x_bins == htr_rate_within.bin_x(i));
    y_idx = find(y_bins == htr_rate_within.bin_y(i));
    occupancy_map(y_idx, x_idx) = occupancy_map(y_idx, x_idx) + htr_rate_within.mean_htr_rate(i);
end

occupancy_map_big = imresize(occupancy_map, [length(y_bins) * upscale, length(x_bins) * upscale], 'nearest');
occ_smooth = imgaussfilt(occupancy_map_big, upscale / 2, 'Padding', 'symmetric', 'FilterDomain', 'spatial');

cmap = 1-(cubehelix(256, 0, 0.8, 1, 1.5));

figure;
imagesc(x_bins, y_bins, occ_smooth);
set(gca, 'YDir', 'normal');
colormap(cmap)
caxis([0 15]);
colorbar
xlabel('X Bin', 'FontSize', 16);
ylabel('Y Bin', 'FontSize', 16);
title('HTR map during trial', 'FontSize', 18);
set(gcf, 'Units', 'centimeters', 'Position', [10, 10, 25, 15]);
set(gca, 'Position', [0.08, 0.1, 0.8, 0.8]);
xticks([]); yticks([]); set(gca, 'ytick', []);
xlabel(''); ylabel('');
h = colorbar;
ylabel(h, 'HTR/min', 'FontSize', 14);
set(h, 'FontSize', 12);
ylabel(h, 'Mean HTR/min', 'FontSize', 14, 'Rotation', -90);
yticks_h = get(h, 'Ticks');
set(h, 'Ticks', [yticks_h(1), yticks_h(end)]);
set(h, 'YTickLabel', {num2str(yticks_h(1), '%.0f'), num2str(yticks_h(end), '%.0f')});

%% DOI occupancy map and Saline occupancy map
% time spent per bin (mean_occupancy, in seconds), grand-averaged across
% mice upstream in fig5_cleaned.Rmd -- same pipeline again, looped over
% the two conditions so both panels get identical styling/color scale
cmap = 1-(cubehelix(256, 0.5, -1, 1.5, 1.0));

frames = {'occupancy_doi_time', 'saline_full'};

for f = 1:length(frames)
    current_frame = eval(frames{f});  % looks up the variable by name (see `frames` above)

    x_coordinates = current_frame.bin_x;
    y_coordinates = current_frame.bin_y;
    mean_frames = current_frame.mean_occupancy;

    x_bins = unique(x_coordinates);
    y_bins = unique(y_coordinates);

    occupancy_map = zeros(length(y_bins), length(x_bins));
    for i = 1:length(x_coordinates)
        x_idx = find(x_bins == x_coordinates(i));
        y_idx = find(y_bins == y_coordinates(i));
        occupancy_map(y_idx, x_idx) = occupancy_map(y_idx, x_idx) + mean_frames(i);
    end

    occupancy_map_big = imresize(occupancy_map, [length(y_bins) * upscale, length(x_bins) * upscale], 'nearest');
    occ_smooth = imgaussfilt(occupancy_map_big, upscale / 2, 'Padding', 'symmetric', 'FilterDomain', 'spatial');

    figure;
    set(gcf, 'Units', 'centimeters', 'Position', [10, 10, 27, 15]);
    set(gca, 'Position', [0.08, 0.1, 0.8, 0.8]);

    imagesc(x_bins, y_bins, occ_smooth);
    set(gca, 'YDir', 'normal');
    colormap(cmap);

    xlim([75, 1120]);
    ylim([30, 610]);
    caxis([0 10]);

    if contains(frames{f}, 'doi', 'IgnoreCase', true)
        title('DOI occupancy map', 'FontSize', 16);
    else
        title('Saline occupancy map', 'FontSize', 16);
    end

    xticks([]); yticks([]); set(gca, 'ytick', []);
    xlabel(''); ylabel('');

    h = colorbar;
    ylabel(h, 'Occupancy (s)', 'FontSize', 14, 'Rotation', -90);
    set(h, 'FontSize', 12);
    set(h, 'Ticks', []);
end
