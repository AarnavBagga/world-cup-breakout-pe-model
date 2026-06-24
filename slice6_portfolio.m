% slice6_portfolio.m  —  Efficient frontier: the transfer window as a PE fund
% Press the green RUN button. Single block. Self-loading (joins both CSVs if needed).
% Each player = an asset (return = NPV per euro of fee). A shared transfer-market
% factor links players so diversification is meaningful. Random long-only budget
% splits trace the efficient frontier; the max-Sharpe mix is the optimal allocation.

% --- 0. Data (joined: needs xg_overperformance + minutes) ---
needLoad = ~exist('players','var');
if ~needLoad, needLoad = ~ismember('xg_overperformance', players.Properties.VariableNames); end
if needLoad
    master = readtable('wc_breakout_players_master_v2.csv','TextType','string');
    stats  = readtable('wc_performance_stats.csv','TextType','string');
    stats.wc_year = [];
    players = innerjoin(master, stats, 'Keys','player');
end
rng(42);

% --- 1. Assumptions ---
hold_years=4; discount_rate=0.10; base_revenue=8; assumed_wage=3;
N_sims=5000; sigma_rev=0.20; sigma_exit=0.30;
sigma_market=0.15;          % shared market factor -> correlation between players
H=hold_years; AF=(1-(1+discount_rate)^(-H))/discount_rate; DH=1/(1+discount_rate)^H;

% risk recipe (same as slice5)
w_over=0.40; w_age=0.25; w_fee=0.20; w_min=0.15;
over_ref=3; age_lo=21; age_hi=33; fee_ref=80; min_ref=600;
sigma_floor=0.5; haircut_strength=0.25;
clamp01 = @(x) max(0, min(1, x));

% --- 2. Investable assets: players with a real, positive fee ---
isAsset = ~isnan(players.transfer_fee_eur_m) & players.transfer_fee_eur_m > 0;
idx = find(isAsset); nA = numel(idx); names = players.player(idx);

% --- 3. Correlated Monte Carlo: return-on-fee draws per player ---
M = sigma_market * randn(N_sims,1);     % market factor, shared across players each sim
R = zeros(N_sims, nA);
for a = 1:nA
    r = players(idx(a),:);
    fee=r.transfer_fee_eur_m; wage=r.est_annual_wage_eur_m; base_exit=r.mv_peak_eur_m;
    over=r.xg_overperformance; age=r.age_at_wc; mins=r.minutes;
    if isnan(wage), wage=assumed_wage; end
    if isnan(base_exit)
        if ~isnan(r.mv_at_wc_eur_m), base_exit=r.mv_at_wc_eur_m; else, base_exit=fee; end
    end
    if isnan(over), r_over=0.5; else, r_over=clamp01(over/over_ref); end
    r_age=clamp01((age-age_lo)/(age_hi-age_lo));
    r_fee=clamp01(fee/fee_ref);
    if isnan(mins), r_min=0.5; else, r_min=clamp01(1-mins/min_ref); end
    sigM    = sigma_floor + (w_over*r_over+w_age*r_age+w_fee*r_fee+w_min*r_min);
    rev_eff = base_revenue*(1-haircut_strength*r_over);
    revMult  = max(0, 1 + sigM*sigma_rev *randn(N_sims,1) + M);   % + shared market shock
    exitMult = max(0, 1 + sigM*sigma_exit*randn(N_sims,1) + M);
    npv = -fee + (rev_eff.*revMult - wage)*AF + (base_exit.*exitMult)*DH;
    R(:,a) = npv / fee;                 % 4-yr return per euro of fee
end
mu  = mean(R);          % 1 x nA expected returns
Sig = cov(R);           % nA x nA covariance

% --- 4. Random long-only portfolios (budget splits summing to 100%) ---
nPort = 20000;
W = rand(nA, nPort); W = W ./ sum(W,1);
pRet = mu * W;                              % expected return of each portfolio
pStd = sqrt(sum((Sig*W).*W, 1));            % risk of each portfolio
Sharpe = pRet ./ pStd;
[bestSharpe, b] = max(Sharpe);  wopt = W(:,b);
pmu = mu; pstd = sqrt(diag(Sig))';

% --- 5. Plot: cloud of portfolios + frontier + players + optimal mix ---
figure('Color','w');
scatter(100*pStd, 100*pRet, 8, Sharpe, 'filled', 'MarkerFaceAlpha',0.30); hold on;
colormap(parula); cb = colorbar; cb.Label.String = 'Sharpe ratio (return / risk)';
scatter(100*pstd, 100*pmu, 95, [0.15 0.15 0.15], 'filled');          % individual players
for a = 1:nA
    text(100*pstd(a)+0.6, 100*pmu(a), names(a), 'FontSize',8, 'FontWeight','bold', ...
         'Color',[0 0 0], 'BackgroundColor',[1 1 1], 'Margin',1, 'Interpreter','none');
end
scatter(100*pStd(b), 100*pRet(b), 260, 'pentagram', ...
        'MarkerFaceColor',[0.85 0.20 0.20], 'MarkerEdgeColor','k', 'LineWidth',1);
text(100*pStd(b)+0.6, 100*pRet(b), 'Optimal mix', 'FontWeight','bold', 'Color',[0.6 0 0]);
xlabel('Risk  (std of 4-yr return, %)', 'FontWeight','bold', 'Color',[0.1 0.1 0.1]);
ylabel('Expected 4-yr return on fee (%)', 'FontWeight','bold', 'Color',[0.1 0.1 0.1]);
title('Transfer window as a fund: efficient frontier', 'FontWeight','bold', 'Color',[0.1 0.1 0.1]);
set(gca,'FontSize',9,'XColor',[0.25 0.25 0.25],'YColor',[0.25 0.25 0.25],'GridColor',[0.85 0.85 0.85]);
grid on; hold off;

% --- 6. Print the optimal allocation ---
fprintf('\n--- Optimal (max-Sharpe) budget allocation ---\n');
[sw, order] = sort(wopt, 'descend');
for k = 1:nA
    fprintf('  %-18s %5.1f%%\n', names(order(k)), 100*sw(k));
end
fprintf('Portfolio: expected return %.0f%%, risk %.0f%%, Sharpe %.2f\n', ...
        100*pRet(b), 100*pStd(b), bestSharpe);
fprintf('(Note: Ochoa excluded as a free transfer - undefined return-on-fee; Gotze had no transfer.)\n');
