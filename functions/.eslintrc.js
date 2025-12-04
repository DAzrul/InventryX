// File: .eslintrc.js

module.exports = {
    root: true,
    env: {
        es6: true,
        node: true,
    },
    extends: [
        "eslint:recommended",
        "plugin:import/errors",
        "plugin:import/warnings",
        "plugin:import/typescript",
        "google",
        "plugin:@typescript-eslint/recommended",
    ],
    parser: "@typescript-eslint/parser",
    parserOptions: {
        project: ["tsconfig.json", "tsconfig.dev.json"],
        sourceType: "module",
    },
    ignorePatterns: [
        "/lib/**/*", // Ignore built files.
        "/generated/**/*", // Ignore generated files.
    ],
    plugins: [
        "@typescript-eslint",
        "import",
    ],
    rules: {
        // Indentasi 4 ruang diaktifkan kembali untuk penyeragaman
        "indent": ["error", 4, { "SwitchCase": 1 }],
        "quotes": ["error", "double"],
        "import/no-unresolved": 0,

        // Matikan aturan ketat untuk deployment yang stabil
        "max-len": "off",
        "@typescript-eslint/ban-ts-comment": "off",
        "padded-blocks": "off",
        "object-curly-spacing": "off",
        "arrow-parens": "off",
        "no-trailing-spaces": "error",
        "eol-last": ["error", "always"],

        // Mematikan aturan yang sering berkonflik dalam Array/Object definition
        "comma-dangle": "off",
    },
};
