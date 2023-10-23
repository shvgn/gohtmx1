/** @type {import('tailwindcss').Config} */
export default {
  // content: ["./*.templ", "./**/*.templ"],
  content: ["./**/*.templ"],
  theme: {
    extend: {},
  },
  plugins: [require("daisyui")],
};
