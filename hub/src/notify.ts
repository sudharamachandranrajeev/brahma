// Phone alerts through ntfy (https://docs.ntfy.sh/publish/#publish-as-json).

export async function sendNtfy(server: string, token: string | undefined, body: object): Promise<void> {
  const res = await fetch(server, {
    method: "POST",
    headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`ntfy answered ${res.status}: ${await res.text()}`);
}
