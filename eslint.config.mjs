import eslint from "@eslint/js";
import perfectionist from "eslint-plugin-perfectionist";
import eslintPrettierRecommended from "eslint-plugin-prettier/recommended";
import globals from "globals";
import tsEsLint from "typescript-eslint";
import { globalIgnores } from "eslint/config";

const config = tsEsLint.config(
  globalIgnores([
    "**/.zig-cache",
    "**/node_modules",
    "**/zig-out",
    "eslint.config.mjs",
  ]),
  eslint.configs.recommended,
  eslintPrettierRecommended,
  perfectionist.configs["recommended-natural"],

  {
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
      },
      parser: tsEsLint.parser,
      parserOptions: {
        ecmaFeatures: {
          jsx: true,
        },
        ecmaVersion: "latest",
        project: ["tsconfig.json"],
        sourceType: "module",
      },
    },
  },

  {
    rules: {
      "@typescript-eslint/ban-ts-comment": ["off"],
      "@typescript-eslint/no-unused-vars": ["off"],
      "object-shorthand": ["error", "always"],
      "perfectionist/sort-imports": [
        "error",
        {
          customGroups: {
            type: {
              react: ["react", "react-*"],
            },
            value: {
              react: ["react", "react-*"],
            },
          },
          groups: [
            "type",
            "react",
            ["builtin", "external"],
            "internal-type",
            "internal",
            ["parent-type", "sibling-type", "index-type"],
            ["parent", "sibling", "index"],
            "object",
            "unknown",
          ],
          newlinesBetween: "always",
          order: "asc",
          type: "natural",
        },
      ],
      "prefer-template": ["error"],
    },
  },
);

export default config;
