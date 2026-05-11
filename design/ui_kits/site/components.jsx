/* Rocketbox site UI kit — components */

const { useState } = React;

const Logo = () => (
  <a href="#" className="topbar__logo">Rocketbox<span className="dot" /></a>
);

const TopBar = ({ screen, setScreen }) => {
  const items = [
    ['home', 'Home'],
    ['catalogue', 'Catalogue'],
    ['membership', 'Membership'],
    ['about', 'About'],
  ];
  return (
    <header className="topbar">
      <Logo />
      <nav className="topbar__nav">
        {items.map(([id, label]) => (
          <a key={id} className={screen === id ? 'is-active' : ''} onClick={() => setScreen(id)}>{label}</a>
        ))}
      </nav>
      <a className="topbar__nav" style={{fontSize:14, fontWeight:500, color:'var(--fg)'}}>Sign in</a>
    </header>
  );
};

const BookCard = ({ book, onOpen }) => (
  <div className="book-card" onClick={() => onOpen && onOpen(book)}>
    <div className="book-card__cover"><img src={`../../assets/${book.cover}`} alt="" /></div>
    <div>
      <div className="book-card__kicker">{book.kicker}</div>
      <div className="book-card__meta">
        <span className="book-card__title">{book.title}</span>
        <span className="book-card__price">${book.price}</span>
      </div>
    </div>
  </div>
);

const ContentsBlock = () => (
  <div className="contents-block">
    <div className="contents-block__cell" style={{background:'var(--signal-green)', color:'var(--on-green)'}}>
      <strong>Do</strong><br/>Reply within 24 hours. Refund first, ask later, when the order is under $40.
    </div>
    <div className="contents-block__cell" style={{background:'var(--signal-red)', color:'var(--on-red)'}}>
      <strong>Don't</strong><br/>Negotiate. Argue the policy. Cc the founder. The customer left already.
    </div>
    <div className="contents-block__cell" style={{background:'var(--signal-yellow)', color:'var(--on-yellow)'}}>
      <strong>Watch</strong><br/>Refunds over $200 — flag for review, don't auto-approve. Easy fraud vector.
    </div>
    <div className="contents-block__cell" style={{background:'var(--signal-pink)', color:'var(--on-pink)'}}>
      <strong>Side note</strong><br/>If you ship outside the US, your refund clock starts on delivery, not order.
    </div>
  </div>
);

const Hero = ({ onPrimary }) => (
  <section className="hero">
    <div>
      <span className="hero__kicker">New book — Refunds &amp; returns</span>
      <h1 className="hero__title">Run a better small business. One short book at a time.</h1>
      <p className="hero__sub">Practical books and lessons on customer service, retention, hiring support, and the operator stuff nobody teaches you.</p>
      <div className="hero__ctas">
        <button className="rb-btn" onClick={onPrimary}>Browse the catalogue</button>
        <button className="rb-btn rb-btn--ghost">Membership — $24/mo</button>
      </div>
    </div>
    <div className="hero__art"><img src="../../assets/book-refunds.svg" alt="" /></div>
  </section>
);

const BuyPanel = ({ book, onBuy }) => (
  <aside className="buy-panel">
    <div className="t-micro">{book.kicker}</div>
    <div className="buy-panel__price">${book.price}</div>
    <div className="buy-panel__meta">{book.pages} pages · read in your browser · download for offline · pay once, keep forever.</div>
    <button className="rb-btn" onClick={onBuy}>Buy — ${book.price}</button>
    <button className="rb-btn rb-btn--ghost">Add to library</button>
  </aside>
);

const MembershipCard = ({ onJoin }) => (
  <div className="membership__card">
    <div className="t-micro" style={{color:'rgba(255,255,255,0.7)', marginBottom:10}}>Membership</div>
    <div className="price">$24 <small>/ month</small></div>
    <ul className="membership__features">
      <li>Every book and lesson in the catalogue</li>
      <li>Monthly live Q&amp;A with the authors</li>
      <li>Private community of 1,200+ operators</li>
      <li>Cancel anytime, keep what you've downloaded</li>
    </ul>
    <button className="membership__btn" onClick={onJoin}>Join Rocketbox</button>
  </div>
);

const FounderCard = ({ initial, name, role, bio }) => (
  <div className="founder">
    <div className="founder__photo"><div>{initial}</div></div>
    <div>
      <h3 className="founder__name">{name}</h3>
      <div className="founder__role">{role}</div>
      <p className="founder__bio">{bio}</p>
    </div>
  </div>
);

const Footer = () => (
  <footer className="footer shell">
    <div className="footer__cols">
      <div className="footer__col">
        <Logo />
        <p className="footer__small" style={{marginTop:14, maxWidth:280}}>Books and lessons for small and medium businesses. Customer service, retention, support operations.</p>
      </div>
      <div className="footer__col">
        <h4>Products</h4>
        <a>Books</a><a>Lessons</a><a>Membership</a><a>Gift a book</a>
      </div>
      <div className="footer__col">
        <h4>Company</h4>
        <a>About</a><a>Writing</a><a>Contact</a>
      </div>
      <div className="footer__col">
        <h4>Legal</h4>
        <a>Terms</a><a>Privacy</a><a>Refunds</a>
      </div>
    </div>
    <div className="footer__small">© 2026 Rocketbox · Made in Portland, OR</div>
  </footer>
);

const Toast = ({ message }) => message ? <div className="toast">{message}</div> : null;

Object.assign(window, { TopBar, Hero, BookCard, ContentsBlock, BuyPanel, MembershipCard, FounderCard, Footer, Toast });
