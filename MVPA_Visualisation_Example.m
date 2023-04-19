% Dot Probe MVPA group-level analysis
% author: zeguo.qiu@uq.net.au

%% Figure1: Plot line graphs
% Temporal MVPA with whole brain channels
data_path = '';
output_path = '';
cd(output_path)

trialtype_names = {'tasktype','visibility'};
colours = parula(6);

for i = 1:length(trialtype_names)
    load([output_path 'group_' trialtype_names{i} '.mat']) % return variables 'res_group, 'res_stat'
    figure('Units','normalized','Position',[0.44,0.42,0.185,0.21])

    times = (res_group.a.fdim.values{1})';
    data = res_group.samples*100; % accuracy (%)
    data_mean = squeeze(mean(data, 1))'; % grand average accuracies across subjects for each time point
    data_se = (std(data)/sqrt(size(data,1)))'; % standard errors

    fill([times; flipud(times)], [data_mean-data_se; flipud(data_mean+data_se)], colours((i-1)*6/3+1,:), 'LineStyle','none', 'FaceAlpha', 0.2);
    hold on
    plot(times, data_mean, 'Color', colours((i-1)*6/3+1,:), 'LineWidth',1.5)

    title(trialtype_names{i})
    xlabel('Time (ms)')
    xlim([times(1) times(358)])
    xline(0, '--')
    ylim([45 70])
    ylabel('accuracy')
    yline(50, '--')
    grid off
    box off
    acc = gca;
    acc.FontSize = 8;
    hold on

    for j = 1:size(data, 2)
        if res_stat.samples(1, j) > 1.6449   % at alpha = 0.05, when z-statistic is above expected mean
            x_data = [times(j)-3.906, times(j)-3.906, times(j)+3.906, times(j)+3.906];
            y_data = [acc.YLim(1)+1, acc.YLim(1)+1.5, acc.YLim(1)+1.5, acc.YLim(1)+1]; %0.8 0.5

            sig_markers = patch('xdata', x_data, 'ydata', y_data);
            sig_markers.FaceAlpha = 1;
            sig_markers.FaceColor = [0.5 0.5 0.5];
            sig_markers.EdgeColor = 'none';

            hold on;
        end
    end
end

