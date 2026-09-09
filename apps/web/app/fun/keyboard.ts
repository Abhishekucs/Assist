import catalog from "./catalog.json";

export type KeyboardDesign = typeof catalog.designs[number];
export type DemoKey = { code: string; macCode: number; label: string; units: number; pan: number };
type KeySpec = [string, number, string, number?];
const specs: KeySpec[][] = [
  [["Escape",53,"esc",1.5],["F1",122,"F1"],["F2",120,"F2"],["F3",99,"F3"],["F4",118,"F4"],["F5",96,"F5"],["F6",97,"F6"],["F7",98,"F7"],["F8",100,"F8"],["F9",101,"F9"],["F10",109,"F10"],["F11",103,"F11"],["F12",111,"F12"],["Delete",117,"del",1.5]],
  [["Backquote",50,"`"],["Digit1",18,"1"],["Digit2",19,"2"],["Digit3",20,"3"],["Digit4",21,"4"],["Digit5",23,"5"],["Digit6",22,"6"],["Digit7",26,"7"],["Digit8",28,"8"],["Digit9",25,"9"],["Digit0",29,"0"],["Minus",27,"−"],["Equal",24,"="],["Backspace",51,"delete",2]],
  [["Tab",48,"tab",1.5],["KeyQ",12,"Q"],["KeyW",13,"W"],["KeyE",14,"E"],["KeyR",15,"R"],["KeyT",17,"T"],["KeyY",16,"Y"],["KeyU",32,"U"],["KeyI",34,"I"],["KeyO",31,"O"],["KeyP",35,"P"],["BracketLeft",33,"["],["BracketRight",30,"]"],["Backslash",42,"\\",1.5]],
  [["CapsLock",57,"caps",1.75],["KeyA",0,"A"],["KeyS",1,"S"],["KeyD",2,"D"],["KeyF",3,"F"],["KeyG",5,"G"],["KeyH",4,"H"],["KeyJ",38,"J"],["KeyK",40,"K"],["KeyL",37,"L"],["Semicolon",41,";"],["Quote",39,"'"],["Enter",36,"return",2.25]],
  [["ShiftLeft",56,"shift",2.25],["KeyZ",6,"Z"],["KeyX",7,"X"],["KeyC",8,"C"],["KeyV",9,"V"],["KeyB",11,"B"],["KeyN",45,"N"],["KeyM",46,"M"],["Comma",43,","],["Period",47,"."],["Slash",44,"/"],["ShiftRight",60,"shift",1.75],["ArrowUp",126,"↑"]],
  [["Fn",63,"fn"],["ControlLeft",59,"ctrl"],["AltLeft",58,"opt"],["MetaLeft",55,"⌘",1.25],["Space",49,"space",4.5],["MetaRight",54,"⌘",1.25],["AltRight",61,"opt"],["ControlRight",62,"ctrl"],["ArrowLeft",123,"←"],["ArrowDown",125,"↓"],["ArrowRight",124,"→"]]
];

export const keyboardRows: DemoKey[][] = specs.map(row => row.map(([code, macCode, label, units = 1], i) => ({
  code, macCode, label, units, pan: (i / (row.length - 1) * 2 - 1) * 0.65
})));
export const keyboardKeys = new Map(keyboardRows.flat().map(key => [key.code, key]));
const modifiers = new Set([96,97,98,100,101,117,51,48,57,56,60,59,62,58,61,55,54,63]);

export function keyColors(design: KeyboardDesign, code: number) {
  const accents = design.id === "classic" ? [53]
    : ["mint", "royal"].includes(design.id) ? [53,36,123,124,125,126]
    : design.id === "dolch" ? [53,36,49] : [53,36];
  const extraModifiers = design.id === "classic" ? [36,42] : design.id === "dolch" ? [50,42] : [];
  const fill = accents.includes(code) ? design.accent
    : modifiers.has(code) || extraModifiers.includes(code) ? design.modifier : design.alpha;
  const linear = [1,3,5].map(index => {
    const value = parseInt(fill.slice(index, index + 2), 16) / 255;
    return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });
  return { fill, ink: linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722 > 0.179 ? "#000000" : "#ffffff" };
}

export function sampleSlot(code: string, variation: number) {
  if (code === "Space") return 3;
  if (code === "Enter" || code === "NumpadEnter") return 4;
  if (code === "Backspace" || code === "Delete") return 5;
  return variation % 3;
}
