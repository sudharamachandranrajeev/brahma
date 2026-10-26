import { handle, type Env } from "./app.ts";

export default { fetch: (req: Request, env: Env) => handle(req, env) };
