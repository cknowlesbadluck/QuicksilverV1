// Vite/Vitest `?raw` imports: load protocol fixtures as strings without Node types.
declare module "*?raw" {
  const content: string;
  export default content;
}
