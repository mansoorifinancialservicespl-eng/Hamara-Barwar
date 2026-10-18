# Hamara-Barwar Marketplace — विकास योजना

यह दस्तावेज़ मौजूदा static landing page से सुरक्षित, साझा ऑनलाइन मार्केटप्लेस तक जाने का चरणबद्ध खाका है।

## अभी की स्थिति
- मौजूदा landing page: `index.html`
- Marketplace foundation branch: `feature/marketplace-foundation`
- इस branch में database schema का शुरुआती draft है। इसे live database में लागू नहीं किया गया है।
- मौजूदा localStorage demo वास्तविक shared registration, login, order storage या payment नहीं है।

## प्रस्तावित तकनीकी ढाँचा
1. **Frontend:** मौजूदा design को बनाए रखते हुए customer/shopkeeper dashboard जोड़ना। उत्पादन उपयोग के लिए frontend को static HTML से modular app में बदलना उचित होगा।
2. **Backend / database:** Supabase Postgres, Row Level Security (RLS), Supabase Storage.
3. **Login:** Supabase Phone Auth द्वारा OTP; production से पहले SMS provider, country settings, rate limits और खर्च की जाँच।
4. **Images:** दुकान/उत्पाद फोटो Supabase Storage में; QR फोटो केवल सार्वजनिक दिखाने की सहमति के साथ।
5. **Orders:** database-side function में कीमत server/database से निकलेगी; ब्राउज़र से भेजी कुल कीमत पर भरोसा नहीं किया जाएगा।
6. **Payments:** भारत के लिए Razorpay या किसी उपयुक्त RBI-compliant payment provider के hosted checkout/UPI integration का मूल्यांकन। Order amount और payment status केवल server-side API/webhook से सत्यापित होंगे। Browser redirect या screenshot को payment proof न मानें।
7. **Marketplace payouts:** यदि प्लेटफ़ॉर्म दुकानदारों को भुगतान बाँटेगा, तो provider का marketplace/split-settlement product, KYC, शुल्क और कानूनी/कर दायित्व अलग से सत्यापित करने होंगे। साधारण payment gateway अपने-आप दुकानदार payout सुविधा नहीं देता।
8. **Hosting:** GitHub Pages केवल static frontend होस्ट कर सकता है; secrets, database logic और payment webhooks वहाँ नहीं रखे जाएँगे। Server-side functions को Supabase Edge Functions या उपयुक्त backend पर deploy करना होगा।

## चरणबद्ध विकास
### चरण A — अकाउंट और सुरक्षा
- Supabase project बनाएँ और project URL/anon key को frontend configuration में रखें; service-role key कभी frontend/GitHub में न रखें।
- Phone OTP sign-in, profile, sign-out और role-safe onboarding बनाएँ।
- दुकानदार की दुकान शुरुआत में `pending` रहे; admin review के बाद ही public listing `active` हो।

### चरण B — दुकान और कैटलॉग
- दुकान का नाम, मालिक का नाम, business phone, address, category, delivery area, hours.
- Product name, description, price, stock, unit, image, active/inactive.
- Owner केवल अपनी दुकान/उत्पाद संपादित कर सके; सार्वजनिक लोग केवल approved active listings पढ़ सकें।

### चरण C — ऑर्डर
- Customer delivery address, items, quantity और note चुन सके।
- Database/server product price की पुष्टि करे और order total स्वयं निकाले।
- Customer अपने ऑर्डर; shopkeeper केवल अपनी दुकान के ऑर्डर देख सके।
- Status flow: pending → accepted → preparing → out_for_delivery → delivered; cancelled/refunded अलग नियंत्रित स्थिति।
- Stock reservation, payment failure और cancellation पर stock release के लिए server-side logic आवश्यक है।

### चरण D — सुरक्षित भुगतान
- Provider account और business verification पूरा करें।
- Server-side order/payment intent बनाएँ; secret key केवल server-side secret store में रखें।
- Signature-verified webhook से payment status बदलें; duplicate webhook को idempotently संभालें।
- Refund, failed payment, COD, reconciliation और audit logs का परीक्षण करें।
- वास्तविक भुगतान को sandbox/test mode में end-to-end जाँचने के बाद ही live करें।

### चरण E — लॉन्च तैयारी
- Privacy policy, terms, cancellation/refund, delivery policy, grievance/contact details.
- दुकानदार onboarding/verification, product moderation, abuse reporting और admin panel.
- Database backups, monitoring, rate limiting, access rules और restore test.
- मोबाइल, धीमे नेटवर्क, OTP abuse, price tampering, unauthorized order access और payment webhook tests.

## महत्त्वपूर्ण सुरक्षा नियम
- कभी भी OTP, UPI PIN, card PIN, CVV, password या provider secret GitHub issue/chat/form में न माँगें।
- UPI QR दिखाना payment gateway integration के समान नहीं है। भुगतान की server-verified पुष्टि ज़रूरी है।
- ग्राहक का delivery address और phone निजी डेटा हैं; public shop listing में इन्हें उजागर न करें।
- शुरुआती SQL schema review/draft है, production security audit या payment integration का विकल्प नहीं।

## अभी अगला कदम
Supabase को ChatGPT में connect करें या Supabase dashboard में नया project बनाएँ। फिर schema को पहले development project में review/test करके लागू करें। Live project में schema बिना review के न चलाएँ।
