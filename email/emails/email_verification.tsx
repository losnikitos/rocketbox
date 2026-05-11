import {
  Body,
  Button,
  Container,
  Head,
  Heading,
  Html,
  Preview,
  Section,
  Tailwind,
  Text,
} from 'react-email';
import { pm } from './utils/postmarkMerge';

export default function EmailVerificationEmail() {
  return (
    <Html lang="en">
      <Tailwind>
        <Head />
        <Body className="bg-zinc-100 font-sans">
          <Preview>Verify your email for Rocketbox</Preview>
          <Container className="mx-auto max-w-[600px] px-4 py-8 pb-12">
            <Section className="overflow-hidden rounded-2xl bg-white shadow-sm">
              <Section className="px-7 py-8 pb-10 text-left">
                <Heading
                  as="h1"
                  className="m-0 mb-6 text-xl font-semibold leading-7 text-zinc-900"
                >
                  Verify your email
                </Heading>

                <Text className="m-0 mb-4 text-base leading-6 text-zinc-800">
                  Hey there,
                </Text>

                <Text className="m-0 mb-4 text-base leading-6 text-zinc-800">
                  This is to confirm that <strong>{pm('user_email')}</strong> is the email you want
                  to use on your account. If you ever lose your password, that&apos;s where
                  we&apos;ll email a reset link.
                </Text>

                <Text className="m-0 mb-4 text-base font-semibold leading-6 text-zinc-900">
                  You must use the button below to confirm that you received this email.
                </Text>

                <Section className="mb-6 text-center">
                  <Button
                    href={pm('verification_url')}
                    className="inline-block rounded-lg bg-zinc-900 px-8 py-3 text-center text-sm font-semibold text-white no-underline"
                  >
                    Yes, use this email for my account
                  </Button>
                </Section>

                <Text className="m-0 mb-2 text-base leading-6 text-zinc-800">
                  Or copy and paste this link:
                </Text>
                <Text className="m-0 mb-6 break-all text-sm leading-6 text-zinc-600">
                  {pm('verification_url')}
                </Text>

                <Section className="my-6 border-t border-zinc-200" />

                <Text className="m-0 text-base leading-6 text-zinc-800">
                  Have questions or need help? Just reply to this email and our support team will
                  help you sort it out.
                </Text>
              </Section>
            </Section>
          </Container>
        </Body>
      </Tailwind>
    </Html>
  );
}
