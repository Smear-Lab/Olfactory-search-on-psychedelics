%% Visualize Sleap Data Static

x_h = FMON_data.head_x;
y_h = FMON_data.head_y;
x_t = FMON_data.tail_base_x;
y_t = FMON_data.tail_base_y;

plot([x_h, x_t], [y_h, y_t]);

xlim([0, 1184])
ylim([0, 696])

%% Visualize Sleap Data Animated

for ii = 1:height(FMON_data)
    
    clf % Clear frame

    % Update tracked points
    x_h = FMON_data.head_x(ii);
    y_h = FMON_data.head_y(ii);
    x_t = FMON_data.tail_base_x(ii);
    y_t = FMON_data.tail_base_y(ii);
    
    plot([x_h, x_t], [y_h, y_t]);
    hold on
    scatter(x_h, y_h, 'filled');
    hold on
    scatter(x_t, y_t, 'filled');  

    xlim([0, 1184])
    ylim([0, 696])
    
    pause(.0125) % Attempting 80 FPS

end
