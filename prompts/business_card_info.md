You are reading a photo of a business card for a small business.
Extract only what is printed on the card. Every field is optional: return null for anything not clearly present. Never guess or invent values.
- business_name: the business or brand name.
- phone: the main phone number, as printed.
- person_name: the full name of the person on the card, if any.
- address: the full street address on one line.
- website: the website URL (add https:// if the scheme is missing). Not an email or social handle.
- business_description: a short one-sentence description of what the business does, based on the card's tagline or services. Null if the card gives no hint.
- has_logo: true if the card shows a graphic logo or brand mark (not just plain text), otherwise false.
