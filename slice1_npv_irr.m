% slice1_npv_irr.m  —  First PE valuation: NPV + IRR for one player
% RUN ORDER: run load_data.m first (so the 'players' table exists).
% If you haven't, this script will read the CSV itself.

%% 0. Get the data ------------------------------------------------------
if ~exist('players','var')
    players = readtable('wc_breakout_players_master_v2.csv','TextType','string');
end

%% 1. Choose a player ---------------------------------------------------
% Pavard has the most complete financials (fee, wage, and market values).
% To try another player, change this name. (Gakpo has no wage on file yet,
% so you'd need to set one before his numbers make sense.)
name = "Benjamin Pavard";
row  = players(players.player == name, :);

%% 2. ASSUMPTIONS — the levers you must justify in your report ----------
% These are NOT data. They are your modelling choices. Change them and
% watch NPV/IRR move; that sensitivity is half the project.
hold_years     = 4;      % years you hold the player before "selling"
discount_rate  = 0.10;   % 10% required return (your cost of capital / hurdle rate)
annual_revenue = 8;      % EURm/yr of on-pitch + commercial value he generates
                         %   <<< placeholder — replace with a justified figure >>>

%% 3. The player's REAL numbers (EURm) ----------------------------------
fee        = row.transfer_fee_eur_m;      % acquisition cost, paid at Year 0
wage       = row.est_annual_wage_eur_m;   % paid every year you hold him
exit_value = row.mv_peak_eur_m;           % resale value when you sell

% Safety nets for missing data (blanks load as NaN):
if isnan(wage),       warning('No wage on file for %s — set one.', name); wage = 0; end
if isnan(exit_value), exit_value = row.mv_at_wc_eur_m; end  % fall back to WC value

%% 4. Build the cash-flow vector, Year 0 ... Year N ---------------------
t        = 0:hold_years;                 % [0 1 2 3 4]
cf       = zeros(1, hold_years+1);
cf(1)    = -fee;                         % Year 0: pay the transfer fee (cash OUT)
cf(2:end)= annual_revenue - wage;        % Years 1..N: revenue earned minus wages paid
cf(end)  = cf(end) + exit_value;         % Year N: also bank the resale value (cash IN)

%% 5. NPV at your discount rate -----------------------------------------
% NPV = sum of each cash flow discounted back to today.
npv      = @(r) sum( cf ./ (1+r).^t );
npv_now  = npv(discount_rate);

%% 6. IRR = the discount rate that makes NPV exactly zero ----------------
% fzero is in base MATLAB, so this works WITHOUT the Financial Toolbox.
irr      = fzero(npv, 0.10);

%% 7. Report ------------------------------------------------------------
fprintf('\n=== %s : PE valuation (Slice 1) ===\n', name);
fprintf('Cash flows (EURm), Year 0..%d:\n   ', hold_years);
fprintf('%+7.2f', cf); fprintf('\n');
fprintf('Assumptions: hold %d yrs | discount %.0f%% | revenue %.1f/yr | exit %.1f\n', ...
        hold_years, discount_rate*100, annual_revenue, exit_value);
fprintf('NPV at %.0f%%: %+.2f EURm\n', discount_rate*100, npv_now);
fprintf('IRR        : %.1f%%\n', irr*100);
if npv_now > 0
    fprintf('Verdict    : NPV positive — beats your %.0f%% hurdle. Worth the deal.\n', discount_rate*100);
else
    fprintf('Verdict    : NPV negative — fails your %.0f%% hurdle on these assumptions.\n', discount_rate*100);
end
