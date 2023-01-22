/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./views/**/*.{html,js,erb}"],
  theme: {
    extend: {},
  },
  plugins: [
    require('@tailwindcss/typography'),
  ],
}