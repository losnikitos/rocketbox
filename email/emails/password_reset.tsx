import {
  Body,
  Button,
  Container,
  Head,
  Heading,
  Html,
  Link,
  Preview,
  Section,
  Tailwind,
  Text,
} from 'react-email';
import { pm } from './utils/postmarkMerge';

export default function PasswordResetEmail() {
  return (
    <Html lang="en">
      <Tailwind>
        <Head />
        <Body className="bg-zinc-100 font-sans">
          <Preview>Reset your Rocketbox password</Preview>
          <Container className="mx-auto max-w-[600px] px-4 py-8 pb-12">
            <Section className="overflow-hidden rounded-2xl bg-white shadow-sm">
              <Section className="px-7 py-8 pb-10 text-left">
                <Heading
                  as="h1"
                  className="m-0 mb-6 text-xl font-semibold leading-7 text-zinc-900"
                >
                  Reset your password
                </Heading>

                <Text className="m-0 mb-4 text-base leading-6 text-zinc-800">
                  Hey there,
                </Text>

                <Text className="m-0 mb-4 text-base leading-6 text-zinc-800">
                  Can&apos;t remember your password for{' '}
                  <strong>{pm('user_email')}</strong>? That&apos;s OK, it happens. Just use the
                  button below to set a new one.
                </Text>

                <Section className="mb-6 text-center">
                  <Button
                    href={pm('reset_password_url')}
                    className="inline-block rounded-lg bg-zinc-900 px-8 py-3 text-center text-sm font-semibold text-white no-underline"
                  >
                    Reset my password
                  </Button>
                </Section>

                <Text className="m-0 mb-2 text-base leading-6 text-zinc-800">
                  Or copy and paste this link into your browser:
                </Text>
                <Text className="m-0 mb-6 break-all text-sm leading-6 text-zinc-600">
                  {pm('reset_password_url')}
                </Text>

                <Text className="m-0 mb-6 text-base leading-6 text-zinc-800">
                  If you did not request a password reset you can safely ignore this email; it
                  expires in 20 minutes. Only someone with access to this email account can reset
                  your password.
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
