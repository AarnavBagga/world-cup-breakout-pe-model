% slice2_all_players.m  —  NPV + IRR for ALL players, ranked into a league table
% RUN ORDER: run load_data.m first (or this script reads the CSV itself).

%% 0. Data --------------------------------------------------------------
if ~exist('players','var')
    players = readtable('wc_breakout_players_master_v2.csv','TextType','string');
end

%% 1. GLOBAL ASSUMPTIONS (same levers as Slice 1, applied to everyone) ---
hold_years     = 4;     % years held before "selling"
discount_rate  = 0.10;  % 10% hurdle rate
annual_revenue = 8;     % EURm/yr value generated  (placeholder, same for all)
assumed_wage   = 3;     % EURm/yr  — used ONLY when a player's real wage is missing

%% 2. Loop over every player --------------------------------------------
n   = height(players);
[NPV, IRR, feeV, wageV, exitV] = deal(nan(n,1));
flag = strings(n,1);

for i = 1:n
    r    = players(i,:);
    fee  = r.transfer_fee_eur_m;
    wage = r.est_annual_wage_eur_m;
    ex   = r.mv_peak_eur_m;
    f    = "";

    % No transfer fee = no acquisition to value (Götze case) -> skip
    if isnan(fee)
        flag(i) = "no transfer (cannot value as acquisition)";
        continue
    end

    % Wage fallback
    if isnan(wage), wage = assumed_wage; f = f + "wage assumed; "; end

    % Exit-value fallback chain: peak market value -> WC value -> pay-back fee
    if isnan(ex)
        if ~isnan(r.mv_at_wc_eur_m)
            ex = r.mv_at_wc_eur_m; f = f + "exit=WC value; ";
        else
            ex = fee;              f = f + "exit=fee (flat); ";
        end
    end

    % Cash flows: Year 0 fee out; Years 1..N revenue minus wage; Year N + resale
    t  = 0:hold_years;
    cf = zeros(1, hold_years+1);
    cf(1)    = -fee;
    cf(2:end)= annual_revenue - wage;
    cf(end)  = cf(end) + ex;

    npv = @(rate) sum(cf ./ (1+rate).^t);
    NPV(i) = npv(discount_rate);
    feeV(i)=fee; wageV(i)=wage; exitV(i)=ex;

    % IRR
    if fee <= 0
        IRR(i) = Inf; f = f + "free transfer (IRR infinite); ";   % paid nothing, all upside
    else
        try, IRR(i) = fzero(npv, 0.10); catch, IRR(i) = NaN; f = f + "IRR not found; "; end
    end

    if f == "", f = "all inputs from data"; end
    flag(i) = f;
end

%% 3. Ranked league table (by NPV, descending) -------------------------
out = table(players.player, players.wc_year, feeV, wageV, exitV, ...
            round(NPV,2), round(IRR*100,1), flag, ...
    'VariableNames', {'player','wc_year','fee','wage','exit','NPV_eurm','IRR_pct','data_flag'});
out = sortrows(out, 'NPV_eurm', 'descend', 'MissingPlacement','last');

disp(out)

% Save the ranking. If the current folder is read-only (e.g. MATLAB's
% Current Folder is "/"), fall back to a temp folder and report where.
outfile = 'valuation_results.csv';
try
    writetable(out, outfile);
    fprintf('Saved ranking to "%s" in current folder:\n  %s\n', outfile, pwd);
catch
    outfile = fullfile(tempdir, 'valuation_results.csv');
    writetable(out, outfile);
    fprintf('Current folder was not writable. Saved instead to:\n  %s\n', outfile);
    fprintf('(Tip: cd into your project folder so files save where you want them.)\n');
end

fprintf('NOTE: rows with a data_flag other than "all inputs from data" lean on an\n');
fprintf('assumption (missing wage or market value). Refine those before quoting numbers.\n');