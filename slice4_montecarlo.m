% slice4b_histgrid.m  —  Monte Carlo NPV histograms for ALL players, side by side
% Press the green RUN button. Single block, runs top-to-bottom.
% Self-contained: recomputes the NPV draws (fast) and plots a 2x5 grid.

% --- data + reproducible randomness ---
if ~exist('players','var')
    players = readtable('wc_breakout_players_master_v2.csv','TextType','string');
end
rng(42);

% --- assumptions (same as slice4) ---
hold_years=4; discount_rate=0.10; base_revenue=8; assumed_wage=3;
N_sims=10000; sigma_rev=0.20; sigma_exit=0.30;
H  = hold_years;
AF = (1-(1+discount_rate)^(-H))/discount_rate;
DH = 1/(1+discount_rate)^H;

% --- Monte Carlo NPV draws for each player ---
n = height(players);
draws = cell(n,1); pLoss = nan(n,1); valued = false(n,1);
for i = 1:n
    r = players(i,:);
    fee = r.transfer_fee_eur_m; wage = r.est_annual_wage_eur_m; base_exit = r.mv_peak_eur_m;
    if isnan(fee), continue; end                      % no transfer (Gotze)
    if isnan(wage), wage = assumed_wage; end
    if isnan(base_exit)
        if ~isnan(r.mv_at_wc_eur_m), base_exit = r.mv_at_wc_eur_m; else, base_exit = fee; end
    end
    revMult  = max(0, 1 + sigma_rev *randn(N_sims,1));
    exitMult = max(0, 1 + sigma_exit*randn(N_sims,1));
    draws{i} = -fee + (base_revenue.*revMult - wage)*AF + (base_exit.*exitMult)*DH;
    pLoss(i) = mean(draws{i} < 0);
    valued(i) = true;
end

% --- shared x-axis range (1st-99th percentile of all draws pooled) ---
pool = sort(vertcat(draws{valued})); M = numel(pool);
xlo = pool(max(1,round(0.01*M)));  xhi = pool(round(0.99*M));

% --- 2 x 5 grid of histograms ---
nCols = 5; nRows = ceil(n/nCols);
figure('Name','Monte Carlo NPV — all players','Color','w');
for i = 1:n
    subplot(nRows, nCols, i);
    nm = players.player(i);
    if ~valued(i)
        axis off;
        text(0.5,0.5, sprintf('%s\n(no transfer)', nm), ...
             'HorizontalAlignment','center', 'FontSize',9.5, 'FontWeight','bold', ...
             'Color',[0.35 0.35 0.35], 'Interpreter','none');
        continue
    end
    histogram(draws{i}, 30, 'BinLimits',[xlo xhi], ...
              'FaceColor',[0.20 0.45 0.70], 'EdgeColor','none', 'FaceAlpha',0.9); hold on;
    yl = ylim; plot([0 0], yl, '-', 'Color',[0.85 0.10 0.10], 'LineWidth',1.6); ylim(yl);
    xlim([xlo xhi]);
    set(gca, 'FontSize',8, 'XColor',[0.25 0.25 0.25], 'YColor',[0.25 0.25 0.25]);
    title(sprintf('%s  (loss %.0f%%)', nm, 100*pLoss(i)), ...
          'Interpreter','none', 'FontSize',9.5, 'FontWeight','bold', 'Color',[0.10 0.10 0.10]);
    if i > (nRows-1)*nCols          % x-label only on the bottom row -> less clutter
        xlabel('NPV (EURm)', 'FontSize',8, 'Color',[0.30 0.30 0.30]);
    end
    hold off;
end
try
    sgtitle('Monte Carlo NPV distributions  —  red line = break-even (NPV = 0)', ...
            'FontWeight','bold', 'FontSize',12, 'Color',[0.10 0.10 0.10]);
catch
end