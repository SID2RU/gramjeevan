# GramJeevan backlog

The factory takes the first unchecked task, one per cycle. Keep tasks small and specific.
Data-only tasks (content.gd) are the safest for a small local AI.

- [ ] In content.gd add 6 more entries to LESSONS about: kindness to animals, road safety, eating fruit and vegetables, respecting elders, saving seeds, and keeping the village pond clean. Use the exact same dictionary format with 3 options and answer 0.
- [ ] In content.gd add a FESTIVALS list of 5 Indian harvest and light festivals, each a dictionary with name and one short sentence. In main.gd show the festival name for the current day in the message when the player taps Join Festival.
- [ ] In game_state.gd add a 20 percent chance of rain at the start of each new day that waters every SEEDED plot. Add the text "It rained today." to the day report.
- [ ] In game_state.gd add a "helped_elder" counter. Add a function help_elder() that costs 1 grain and gives 1 joy once per day. Reset the daily flag in next_phase.
- [ ] In main.gd add a Help Elder button next to the market button that calls help_elder().
