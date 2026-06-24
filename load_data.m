% load_data.m  —  Load the World Cup breakout PE datasets into MATLAB
% HOW TO USE: put this file in the SAME folder as the two CSV files,
% then press the green Run button (or type  load_data  in the Command Window).

% 1. Read the two CSV files into tables.
%    'TextType','string' makes text columns nicer to work with than the default.
master = readtable('wc_breakout_players_master_v2.csv', 'TextType', 'string');
stats  = readtable('wc_performance_stats.csv',          'TextType', 'string');

% 2. Both files have a 'wc_year' column. Drop the duplicate from one of them
%    so the names don't clash when we join.
stats.wc_year = [];

% 3. Join the two tables into one, matched on the shared 'player' column.
players = innerjoin(master, stats, 'Keys', 'player');

% 4. Quick sanity check — should print 10 players.
fprintf('Loaded %d players across %d columns.\n', height(players), width(players));

% 5. Peek at a few key columns.
disp(players(:, {'player','wc_year','transfer_fee_eur_m','xg','xg_overperformance'}));

% ---- How to use the table once it's loaded ----
%   One whole column:        players.transfer_fee_eur_m
%   One player's full row:    players(players.player == "Cody Gakpo", :)
%   Only the 2022 players:    players(players.wc_year == 2022, :)
%   Players with xG data:     players(~isnan(players.xg), :)
%
% Reminder: blank cells are NaN (numbers) or <missing> (text). When you do
% maths later (NPV, IRR), use functions like sum(...,'omitnan') or check
% isnan(...) so the blanks don't break your calculations.
