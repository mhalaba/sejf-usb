# Polityka bezpieczeństwa

## Wspierane wersje

| Wersja | Poprawki bezpieczeństwa |
|---|---|
| 1.2.x | ✅ |
| < 1.2 | ❌ — zaktualizuj |

## Zgłaszanie podatności

**Nie zgłaszaj podatności w publicznych Issues.**

Użyj prywatnego zgłoszenia: zakładka **Security → Report a vulnerability** w tym repozytorium (GitHub Private Vulnerability Reporting). Opisz:
- czego dotyczy problem (kryptografia, format sejfu, komunikacja z YubiKeyem, interfejs, budowanie);
- jak go odtworzyć (najlepiej na testowym sejfie i programowym kluczu z `Tests/main.swift`);
- jaki jest wpływ (odczyt danych bez klucza/hasła, utrata danych, awaria…).

**Nigdy nie wysyłaj prawdziwego sejfu, haseł ani haseł odzyskiwania.**

## Zakres

Model zagrożeń, kryptografia i znane ograniczenia: [Docs/03-Bezpieczenstwo.md](Docs/03-Bezpieczenstwo.md). Format plików: [Docs/04-Specyfikacja-formatu.md](Docs/04-Specyfikacja-formatu.md).

Poza zakresem: zainfekowany komputer użytkownika, fizyczny dostęp do odblokowanego sejfu, utrata wszystkich kluczy i hasła odzyskiwania.
