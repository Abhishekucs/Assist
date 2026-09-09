# Keyboard catalog and reference coverage

Reference inspected: [getkeeby.com](https://getkeeby.com/), September 8–9, 2026.
Public website build: `/assets/index-BhERCFGE.js`. Its switch catalog lists 22
profiles; its typing-test picker exposes 14. Availability in Keeby's native app
is separate from availability and redistribution rights on the website.

Assist retains Soft, Thock, Clicky, and Typewriter and adds ten recorded switches.
These ten use the original MIT-licensed [kbsim source](https://github.com/tplai/kbsim/tree/ba103f3b0afa9dab80447aa2e7e2ed80b6bd80e4/src/assets/audio),
with source/output hashes and license bundled in `Resources/Sounds`. Matching a
switch type does not mean these files are identical to Keeby's processed audio.

| Keeby reference profile | Assist coverage |
| --- | --- |
| Durock Alpaca | Recorded Alpaca pack |
| Gateron Ink Black | Recorded Ink Black pack |
| Gateron Ink Red | Recorded Ink Red pack |
| Gateron Turquoise Tealios | Recorded Turquoise Tealios pack |
| NovelKeys Cream | Recorded Cream pack |
| Drop Holy Panda | Recorded Holy Panda pack |
| Kailh Box Navy | Recorded Box Navy pack |
| IBM Buckling Spring | Recorded Buckling Spring pack |
| Topre Classic | Recorded Topre pack |
| Alps SKCM Blue | Recorded SKCM Blue pack |
| Akko Piano Pro | Not bundled: contributor recording; redistribution license not verified |
| Keychron K2 Max / K Pro Red | Not bundled: redistribution license not verified |
| Keychron K2 Max / K Pro Brown | Not bundled: contributor audio sprite; redistribution license not verified |
| Quirky Lizard | Not bundled: redistribution license not verified |
| IQUNIX MQ80 | Not offered by the inspected typing-test picker; redistribution license not verified |
| Lofree Flow 2 Surfer | Not offered by the inspected typing-test picker; redistribution license not verified |
| Lofree Flow 2 Void | Not offered by the inspected typing-test picker; redistribution license not verified |
| Lofree Flow 2 Pulse | Not offered by the inspected typing-test picker; redistribution license not verified |
| Akko CS Jelly Black | Not offered by the inspected typing-test picker; redistribution license not verified |
| Akko V3 Cream Yellow Pro | Not offered by the inspected typing-test picker; redistribution license not verified |
| Akko Clicky Pink | Not offered by the inspected typing-test picker; redistribution license not verified |
| Aflion Carrot Orange | Not offered by the inspected typing-test picker; redistribution license not verified |

The website credits Alice for Piano Pro, Himanshu for the K Pro Brown audio and
keyboard component, and Alex for MQ80. A contributor credit or publicly reachable
file is not itself a redistribution license. No downloads of Keeby's native app,
private resources, or access-controlled assets were used. Adding the remaining
recordings requires a usable source and confirmed redistribution rights.

## Native keyboard designs

The reference's keyboard component defines six palettes: Classic, Mint, Royal,
Dolch, Sand, and Scarlet. All six are implemented as native SwiftUI keycaps in
Assist, alongside Match Assist. They share the existing compact US ANSI layout,
key highlighting, pointer/fixed placement, and one-second idle hide. These are
native interpretations, not imported artwork or additional physical layouts.

| Palette | Letter keys | Modifier keys | Accent keys |
| --- | --- | --- | --- |
| Classic | `#F5F5F5` | `#737373` | `#F57644` |
| Mint | `#EEEEEE` | `#447B82` | `#86C8AC` |
| Royal | `#324974` | `#3A3B35` | `#E4D440` |
| Dolch | `#4F5E78` | `#3E3B4C` | `#D73E42` |
| Sand | `#EFEFEF` | `#893D36` | `#C94E41` |
| Scarlet | `#E4D7D7` | `#D5868A` | `#E1E1E1` |

Source colors and key groupings follow the supplied reference; legends use
contrasting black/white for readability at the smaller size. Native rounded
keycaps provide depth without importing web code or drawing custom UI icons.
No claim is made to cover every visualizer mode or artwork in Keeby's native app.
