import {
    S_nil
} from './header';

let current_values = [];

export function values1(x) {
    current_values = [x];
    return x;
}

export function values(...args) {
    current_values = args;
    return args.length === 0 ? S_nil : args[0];
}

export function CL_values(...args) {
    return values(...args);
}

export function currentValues() {
  return current_values;
}

export function restoreValues(values) {
  current_values = values;
}

export function CL_multipleValueCall(fn, ...args) {
    const vector = [];
    for (let i = 0; i < args.length - 1; i++) {
        vector.push(args[i]);
    }
    return fn(...vector.concat(current_values));
}