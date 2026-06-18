// Список разрешённых российских почтовых провайдеров (РФ-закон 406-ФЗ).
// Переопределяется через env ALLOWED_EMAIL_DOMAINS (через запятую).
const DEFAULT_ALLOWED: readonly string[] = [
  "mail.ru",
  "bk.ru",
  "list.ru",
  "inbox.ru",
  "internet.ru",
  "yandex.ru",
  "ya.ru",
  "rambler.ru",
  "lenta.ru",
  "autorambler.ru",
  "myrambler.ru",
  "ro.ru",
  "vk.com",
];

function buildAllowedSet(): Set<string> {
  const envVal = process.env["ALLOWED_EMAIL_DOMAINS"];
  if (envVal && envVal.trim().length > 0) {
    return new Set(
      envVal
        .split(",")
        .map((d) => d.trim().toLowerCase())
        .filter((d) => d.length > 0)
    );
  }
  return new Set(DEFAULT_ALLOWED);
}

// Разрешённые домены (вычисляется один раз при старте)
const ALLOWED_DOMAINS: Set<string> = buildAllowedSet();

/**
 * Проверяет, что домен email входит в список разрешённых российских провайдеров.
 * @param email — уже прошедший базовую Zod-валидацию адрес
 */
export function isAllowedEmailDomain(email: string): boolean {
  const atIdx = email.lastIndexOf("@");
  if (atIdx === -1) return false;
  const domain = email.slice(atIdx + 1).toLowerCase();
  return ALLOWED_DOMAINS.has(domain);
}

/**
 * Форматированный список для сообщения об ошибке (первые 5, затем "…").
 */
export function allowedDomainsHint(): string {
  const list = [...ALLOWED_DOMAINS].slice(0, 5);
  return list.join(", ");
}
