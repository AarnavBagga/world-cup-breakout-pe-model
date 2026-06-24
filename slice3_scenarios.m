% slice3_scenarios.m  —  Upside / Base / Downside NPV + IRR for every player
% Just press the green RUN button (or F5). This file has no section breaks,
% so it always runs top-to-bottom. Run load_data.m first if you can; if not,
% this script reads the CSV itself.

% --- 0. Data ---
if ~exist('players','var')
    players = readtable('wc_breakout_players_master_v2.csv','TextType','string');
end

% --- 1. Base assumptions (same central case as Slice 2) ---
hold_years    = 4;
discount_rate = 0.10;
base_revenue  = 8;     % EURm/yr value generated (central)
assumed_wage  = 3;     % used only when a player's real wage is missing

% --- 2. Scenario multipliers on the two uncertain drivers ---
% Downside = regression/injury; Upside = he kicks on and value climbs.
scen_names = ["Downside","Base","Upside"];
rev_mult   = [0.6, 1.0, 1.3];   % multiplier on annual revenue
exit_mult  = [0.5, 1.0, 1.4];   % multiplier on resale (market) value
nS = numel(rev_mult);

% --- 3. Loop players x scenarios ---
n    = height(players);
NPV  = nan(n, nS);
IRR  = nan(n, nS);
flag = strings(n,1);
t    = 0:hold_years;

for i = 1:n
    r    = players(i,:);
    fee  = r.transfer_fee_eur_m;
    wage = r.est_annual_wage_eur_m;
    base_exit = r.mv_peak_eur_m;
    f = "";

    if isnan(fee)                      % no transfer = nothing to value (Gotze)
        flag(i) = "no transfer";  continue
    end
    if isnan(wage), wage = assumed_wage; f = f + "wage assumed; "; end
    if isnan(base_exit)                % exit fallback: peak -> WC value -> fee
        if ~isnan(r.mv_at_wc_eur_m), base_exit = r.mv_at_wc_eur_m; f = f + "exit=WC value; ";
        else,                        base_exit = fee;             f = f + "exit=fee; "; end
    end

    for s = 1:nS
        revenue = base_revenue * rev_mult(s);
        exitv   = base_exit    * exit_mult(s);
        cf = zeros(1, hold_years+1);
        cf(1)    = -fee;
        cf(2:end)= revenue - wage;
        cf(end)  = cf(end) + exitv;

        npv = @(x) sum(cf ./ (1+x).^t);
        NPV(i,s) = npv(discount_rate);
        if fee <= 0
            IRR(i,s) = Inf;            % free transfer
        else
            try, IRR(i,s) = fzero(npv, 0.10); catch, IRR(i,s) = NaN; end
        end
    end
    if f == "", f = "all inputs from data"; end
    flag(i) = f;
end

% --- 4. On-screen table: NPV range + base IRR + swing ---
swing = NPV(:,3) - NPV(:,1);                       % upside minus downside
rangeTbl = table(players.player, round(NPV(:,1),1), round(NPV(:,2),1), round(NPV(:,3),1), ...
             round(IRR(:,2)*100,1), round(swing,1), flag, ...
   'VariableNames', {'player','NPV_down','NPV_base','NPV_up','IRR_base_pct','NPV_swing','flag'});
rangeTbl = sortrows(rangeTbl, 'NPV_base', 'descend', 'MissingPlacement','last');
disp(rangeTbl)

% --- 5. Save full results (all three IRRs too) ---
full = table(players.player, round(NPV(:,1),2), round(NPV(:,2),2), round(NPV(:,3),2), ...
             round(IRR(:,1)*100,1), round(IRR(:,2)*100,1), round(IRR(:,3)*100,1), flag, ...
   'VariableNames', {'player','NPV_down','NPV_base','NPV_up', ...
                     'IRR_down_pct','IRR_base_pct','IRR_up_pct','flag'});
full = sortrows(full, 'NPV_base', 'descend', 'MissingPlacement','last');
outfile = 'scenario_results.csv';
try
    writetable(full, outfile);
    fprintf('Saved scenarios to "%s" in:\n  %s\n', outfile, pwd);
catch
    outfile = fullfile(tempdir, 'scenario_results.csv');
    writetable(full, outfile);
    fprintf('Current folder not writable; saved to:\n  %s\n', outfile);
end