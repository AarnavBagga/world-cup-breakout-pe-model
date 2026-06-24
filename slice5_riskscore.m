% slice5_riskscore.m  —  Per-player Breakout/Risk score feeding the Monte Carlo
% Press the green RUN button. Single block. Self-loading (joins both CSVs if needed).
% Idea: each player's risk is built from REAL signals (xG overperformance, age,
% fee, WC minutes). Riskier players get a WIDER distribution AND a downward
% haircut on expected output (overperformers regress), instead of one shared sigma.

% --- 0. Data: need the joined table (performance cols live in the stats file) ---
needLoad = ~exist('players','var');
if ~needLoad, needLoad = ~ismember('xg_overperformance', players.Properties.VariableNames); end
if needLoad
    master = readtable('wc_breakout_players_master_v2.csv','TextType','string');
    stats  = readtable('wc_performance_stats.csv','TextType','string');
    stats.wc_year = [];
    players = innerjoin(master, stats, 'Keys','player');
end
rng(42);

% --- 1. Assumptions (same engine as slice4) ---
hold_years=4; discount_rate=0.10; base_revenue=8; assumed_wage=3;
N_sims=10000; sigma_rev=0.20; sigma_exit=0.30;
H=hold_years; AF=(1-(1+discount_rate)^(-H))/discount_rate; DH=1/(1+discount_rate)^H;

% --- 2. Risk-score recipe (edit weights/refs to taste; they sum to 1) ---
w_over=0.40; w_age=0.25; w_fee=0.20; w_min=0.15;     % component weights
over_ref=3; age_lo=21; age_hi=33; fee_ref=80; min_ref=600;   % normalisers
sigma_floor=0.5;        % risk 0 -> 0.5x sigma, risk 100 -> 1.5x sigma
haircut_strength=0.25;  % max revenue haircut for a full xG-overperformer
clamp01 = @(x) max(0, min(1, x));

% --- 3. Build per-player risk score + sim parameters, then Monte Carlo ---
n = height(players);
[risk, sigMult, meanNPV, pLoss, VaR5, feeV] = deal(nan(n,1));
flag = strings(n,1);

for i = 1:n
    r = players(i,:);
    fee = r.transfer_fee_eur_m; wage = r.est_annual_wage_eur_m; base_exit = r.mv_peak_eur_m;
    over = r.xg_overperformance; age = r.age_at_wc; mins = r.minutes;
    f = "";
    if isnan(fee), flag(i) = "no transfer"; continue; end
    if isnan(wage), wage = assumed_wage; f = f + "wage assumed; "; end
    if isnan(base_exit)
        if ~isnan(r.mv_at_wc_eur_m), base_exit = r.mv_at_wc_eur_m; f = f + "exit=WC value; ";
        else,                        base_exit = fee;             f = f + "exit=fee; "; end
    end

    % --- risk components, each mapped to 0..1 (1 = riskiest) ---
    if isnan(over), r_over = 0.5; f = f + "no xG (regression neutral); ";
    else,           r_over = clamp01(over / over_ref); end          % only positive overperf adds risk
    r_age = clamp01((age - age_lo) / (age_hi - age_lo));
    r_fee = clamp01(fee / fee_ref);
    if isnan(mins), r_min = 0.5; else, r_min = clamp01(1 - mins/min_ref); end

    risk(i) = 100 * (w_over*r_over + w_age*r_age + w_fee*r_fee + w_min*r_min);

    % --- map risk -> wider sigma; map overperformance -> expected-output haircut ---
    sigMult(i) = sigma_floor + risk(i)/100;            % 0.5x .. 1.5x
    rev_eff    = base_revenue * (1 - haircut_strength*r_over);   % overperformers regress

    % --- Monte Carlo with this player's own parameters ---
    revMult  = max(0, 1 + sigma_rev *sigMult(i)*randn(N_sims,1));
    exitMult = max(0, 1 + sigma_exit*sigMult(i)*randn(N_sims,1));
    npvDraws = -fee + (rev_eff.*revMult - wage)*AF + (base_exit.*exitMult)*DH;

    meanNPV(i) = mean(npvDraws);
    pLoss(i)   = mean(npvDraws < 0);
    s = sort(npvDraws); VaR5(i) = s(max(1,round(0.05*N_sims)));
    feeV(i) = fee;
    if f == "", f = "all inputs from data"; end
    flag(i) = f;
end

% --- 4. Risk-adjusted ranking table ---
out = table(players.player, round(risk,0), round(sigMult,2), round(meanNPV,1), ...
            round(100*pLoss,1), round(VaR5,1), flag, ...
   'VariableNames', {'player','risk_score','sigma_mult','meanNPV','probLoss_pct','VaR5_eurm','flag'});
out = sortrows(out, 'meanNPV', 'descend', 'MissingPlacement','last');
disp(out)
outfile = 'riskadjusted_results.csv';
try, writetable(out, outfile); fprintf('Saved to "%s" in %s\n', outfile, pwd);
catch, outfile = fullfile(tempdir,outfile); writetable(out,outfile); fprintf('Saved to %s\n',outfile); end

% --- 5. Capstone chart: risk vs risk-adjusted return ---
ok = ~isnan(risk);
figure('Color','w');

% green -> amber -> red colormap: low loss = safe (green), high loss = risky (red)
key  = [0.13 0.60 0.30;  0.95 0.80 0.20;  0.80 0.15 0.15];
xq   = linspace(0,1,256)';
cmap = [interp1(linspace(0,1,3),key(:,1),xq), ...
        interp1(linspace(0,1,3),key(:,2),xq), ...
        interp1(linspace(0,1,3),key(:,3),xq)];
colormap(cmap);

scatter(risk(ok), meanNPV(ok), 110, 100*pLoss(ok), 'filled', ...
        'MarkerEdgeColor',[0.25 0.25 0.25], 'LineWidth',0.75); hold on;
caxis([0 100]);                                          % fix colour scale to 0-100% loss
plot(xlim, [0 0], '--', 'Color',[0.5 0.5 0.5], 'LineWidth',1.2);   % break-even line
nm = players.player;
for i = find(ok)'
    text(risk(i)+1.5, meanNPV(i), nm(i), 'FontSize',8, 'FontWeight','bold', ...
         'Color',[0 0 0], 'BackgroundColor',[1 1 1], 'Margin',1, 'Interpreter','none');
end
cb = colorbar; cb.Label.String = 'Probability of loss (%)';
xlabel('Risk score  (0 = safe,  100 = risky)', 'FontWeight','bold', 'Color',[0.10 0.10 0.10]);
ylabel('Mean risk-adjusted NPV (EURm)', 'FontWeight','bold', 'Color',[0.10 0.10 0.10]);
title('Breakout players: risk vs risk-adjusted return', 'FontWeight','bold', 'Color',[0.10 0.10 0.10]);
set(gca, 'FontSize',9, 'XColor',[0.25 0.25 0.25], 'YColor',[0.25 0.25 0.25], ...
         'GridColor',[0.85 0.85 0.85]);
grid on; hold off;