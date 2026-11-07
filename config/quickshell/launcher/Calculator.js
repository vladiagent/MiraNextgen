.pragma library

function calculate(input) {
    const source = input.trim().replace(/×/g, "*").replace(/÷/g, "/");
    if (!source || !/[0-9]/.test(source) || !/[+*/%^()-]/.test(source)) return null;
    if (source.length > 256 || /[^0-9.eE+*/%^()\s-]/.test(source)) return null;
    let pos = 0, depth = 0, steps = 0;
    function skip() { while (/\s/.test(source[pos] || "") && pos < source.length) pos++; }
    function take(token) { skip(); if (source.slice(pos, pos + token.length) === token) { pos += token.length; return true; } return false; }
    function primary() {
        if (++steps > 256 || ++depth > 32) throw Error("Expression is too complex");
        let value;
        if (take("(")) { value = sum(); if (!take(")")) throw Error("Missing closing parenthesis"); }
        else {
            skip();
            const match = /^(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?/.exec(source.slice(pos));
            if (!match) throw Error("Complete the expression");
            pos += match[0].length; value = Number(match[0]);
        }
        depth--; return value;
    }
    function power() { let left = primary(); if (take("**") || take("^")) left = Math.pow(left, unary()); return left; }
    function unary() { if (++steps > 256) throw Error("Expression is too complex"); if (take("+")) return unary(); if (take("-")) return -unary(); return power(); }
    function product() {
        let value = unary();
        while (true) {
            skip(); if (source.slice(pos, pos + 2) === "**") break;
            if (take("*")) value *= unary();
            else if (take("/")) { const divisor = unary(); if (divisor === 0) throw Error("Cannot divide by zero"); value /= divisor; }
            else if (take("%")) { const divisor = unary(); if (divisor === 0) throw Error("Cannot divide by zero"); value %= divisor; }
            else break;
        }
        return value;
    }
    function sum() { let value = product(); while (true) { if (take("+")) value += product(); else if (take("-")) value -= product(); else break; } return value; }
    try {
        let value = sum(); skip();
        if (pos !== source.length) throw Error("Complete the expression");
        if (!Number.isFinite(value)) throw Error("Result is outside the supported range");
        if (Object.is(value, -0)) value = 0;
        return { ok: true, value: String(Number(value.toPrecision(12))), expression: source };
    } catch (error) { return { ok: false, error: error.message }; }
}
