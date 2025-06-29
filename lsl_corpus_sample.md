
# 📘 LSL Corpus – Complete Reference (Markdown Extract)
_Automatically generated corpus – CC-BY-SA 3.0 – Source: wiki.secondlife.com_

---

## 📌 Introduction to LSL

**Linden Scripting Language (LSL)** is the scripting language used in Second Life to control object behavior, handle user interaction, communicate between objects, and access world features.

---

## 📚 Data Types

| Type    | Description                        |
|---------|------------------------------------|
| integer | Whole numbers                      |
| float   | Floating-point numbers             |
| string  | Text                               |
| key     | UUIDs or asset references          |
| vector  | 3D coordinates (x, y, z)           |
| rotation| Quaternion for rotation            |
| list    | Heterogeneous sequences of values  |

---

## ⚙️ Control Structures

- `if`, `else`, `for`, `while`, `do`, `state`, `jump`, `return`
- State management: `state default;`, `state myState;`
- No switch-case support
- No ternary operator support

---

## 🚦 Events

| Event            | Description                                |
|------------------|--------------------------------------------|
| state_entry()    | Called when a script enters a new state    |
| touch_start(n)   | Triggered when an object is touched        |
| listen(...)      | Triggered when a chat message is received  |
| timer()          | Triggered at interval set by llSetTimer    |

---

## 🔧 Common LSL Functions (Extract)

```lsl
llSay(integer channel, string message)
    // Sends message to nearby chat
llSetTimerEvent(float sec)
    // Sets the interval for timer() event
llGetPos()
    // Returns vector position of the object
llMoveToTarget(vector target, float strength)
    // Moves the object to target (if physical)
```

More at: https://wiki.secondlife.com/wiki/Category:LSL_Functions

---

## 🌐 Web APIs (REST)

- Registration API – create accounts via website
- Map API – retrieve map tile data
- Media Plugin API – control embedded media
- Marketplace API – limited public info
- Inventory API – deprecated

More at: https://wiki.secondlife.com/wiki/APIs_and_Web_Services_Portal

---

## 🧪 Code Examples

```lsl
default {
    state_entry() {
        llSay(0, "Hello, Avatar!");
    }

    touch_start(integer count) {
        llSay(0, "Touched.");
    }
}
```

---

## 🏷 License & Attribution

This corpus is built from publicly available documentation licensed under [Creative Commons BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/).

All content originally from: [wiki.secondlife.com](https://wiki.secondlife.com)
