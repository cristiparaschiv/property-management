import React from 'react';
import { Typography, Card, Divider, Button } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';

const { Title, Paragraph, Text } = Typography;

const TermsOfService = () => {
  const navigate = useNavigate();

  return (
    <div
      style={{
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 50%, #10b981 100%)',
        padding: '40px 20px',
      }}
    >
      <div style={{ maxWidth: 800, margin: '0 auto' }}>
        <Button
          type="link"
          icon={<ArrowLeftOutlined />}
          onClick={() => navigate('/login')}
          style={{ color: '#fff', marginBottom: 16, padding: 0 }}
        >
          Înapoi la autentificare
        </Button>

        <Card>
          <Typography>
            <Title level={2}>Termeni și Condiții de Utilizare</Title>
            <Text type="secondary">Ultima actualizare: {new Date().toLocaleDateString('ro-RO')}</Text>

            <Divider />

            <Title level={4}>1. Acceptarea termenilor</Title>
            <Paragraph>
              Prin accesarea și utilizarea aplicației Domistra („Serviciul"), acceptați să fiți
              obligat de acești Termeni și Condiții de Utilizare. Dacă nu sunteți de acord cu
              acești termeni, vă rugăm să nu utilizați Serviciul.
            </Paragraph>

            <Title level={4}>2. Descrierea Serviciului</Title>
            <Paragraph>
              Domistra este un sistem de management al proprietăților care oferă:
              <ul>
                <li>Gestionarea informațiilor despre chiriași</li>
                <li>Evidența facturilor emise și primite</li>
                <li>Urmărirea contoarelor și a consumurilor de utilități</li>
                <li>Calculul automat al costurilor pentru utilități</li>
                <li>Generarea de facturi și rapoarte</li>
                <li>Backup în cloud prin integrarea cu Google Drive</li>
                <li>Notificări pentru facturi scadente</li>
              </ul>
            </Paragraph>

            <Title level={4}>3. Cont de utilizator</Title>
            <Paragraph>
              <Text strong>3.1. Înregistrare:</Text> Pentru a utiliza Serviciul, trebuie să aveți
              un cont creat de administrator. Sunteți responsabil pentru păstrarea confidențialității
              credențialelor de acces.
            </Paragraph>
            <Paragraph>
              <Text strong>3.2. Securitate:</Text> Trebuie să ne notificați imediat despre orice
              utilizare neautorizată a contului dumneavoastră sau despre orice altă breșă de securitate.
            </Paragraph>
            <Paragraph>
              <Text strong>3.3. Responsabilitate:</Text> Sunteți responsabil pentru toate activitățile
              care au loc în contul dumneavoastră.
            </Paragraph>

            <Title level={4}>4. Utilizare acceptabilă</Title>
            <Paragraph>
              Vă angajați să nu:
              <ul>
                <li>Utilizați Serviciul în scopuri ilegale sau neautorizate</li>
                <li>Încercați să accesați sisteme sau date la care nu aveți dreptul</li>
                <li>Transmiteți viruși sau cod malițios</li>
                <li>Încercați să perturbați sau să supraîncărcați serverele</li>
                <li>Colectați informații despre alți utilizatori fără consimțământ</li>
                <li>Utilizați Serviciul pentru spam sau hărțuire</li>
                <li>Încălcați drepturile de proprietate intelectuală</li>
              </ul>
            </Paragraph>

            <Title level={4}>5. Datele dumneavoastră</Title>
            <Paragraph>
              <Text strong>5.1. Proprietate:</Text> Rămâneți proprietarul tuturor datelor pe care
              le introduceți în Serviciu.
            </Paragraph>
            <Paragraph>
              <Text strong>5.2. Backup:</Text> Vă recomandăm să efectuați backup-uri regulate
              ale datelor. Funcționalitatea de backup în Google Drive este disponibilă pentru
              acest scop.
            </Paragraph>
            <Paragraph>
              <Text strong>5.3. Exactitate:</Text> Sunteți responsabil pentru exactitatea datelor
              introduse, inclusiv informațiile despre chiriași și facturi.
            </Paragraph>

            <Title level={4}>6. Integrări cu servicii terțe</Title>
            <Paragraph>
              <Text strong>6.1. Google Drive:</Text> Când utilizați funcționalitatea de backup
              în Google Drive, acceptați și Termenii de Serviciu ai Google. Noi nu suntem
              responsabili pentru serviciile Google.
            </Paragraph>
            <Paragraph>
              <Text strong>6.2. BNR:</Text> Cursurile de schimb valutar sunt obținute de la
              Banca Națională a României și sunt furnizate „așa cum sunt".
            </Paragraph>

            <Title level={4}>7. Proprietate intelectuală</Title>
            <Paragraph>
              Serviciul și conținutul original, caracteristicile și funcționalitatea sunt și
              vor rămâne proprietatea exclusivă a Domistra și a licențiatorilor săi. Serviciul
              este protejat de legile dreptului de autor și alte legi ale proprietății intelectuale.
            </Paragraph>

            <Title level={4}>8. Limitarea răspunderii</Title>
            <Paragraph>
              <Text strong>8.1.</Text> Serviciul este furnizat „așa cum este" și „după disponibilitate",
              fără garanții de niciun fel, explicite sau implicite.
            </Paragraph>
            <Paragraph>
              <Text strong>8.2.</Text> Nu garantăm că Serviciul va fi neîntrerupt, sigur sau
              fără erori.
            </Paragraph>
            <Paragraph>
              <Text strong>8.3.</Text> Nu suntem responsabili pentru:
              <ul>
                <li>Pierderea de date cauzată de defecțiuni sau de lipsa backup-urilor</li>
                <li>Decizii de afaceri bazate pe informațiile din Serviciu</li>
                <li>Daune indirecte, incidentale sau consecutive</li>
                <li>Întreruperi ale serviciului datorate întreținerii sau forței majore</li>
              </ul>
            </Paragraph>

            <Title level={4}>9. Despăgubire</Title>
            <Paragraph>
              Sunteți de acord să ne despăgubiți și să ne exonerați de răspundere pentru orice
              pretenții, daune sau cheltuieli (inclusiv onorarii de avocat) care rezultă din
              utilizarea Serviciului sau încălcarea acestor Termeni.
            </Paragraph>

            <Title level={4}>10. Modificări ale Serviciului</Title>
            <Paragraph>
              Ne rezervăm dreptul de a modifica sau întrerupe Serviciul (sau orice parte a acestuia)
              în orice moment, cu sau fără notificare. Nu vom fi răspunzători față de dumneavoastră
              sau față de terți pentru orice modificare, suspendare sau întrerupere a Serviciului.
            </Paragraph>

            <Title level={4}>11. Modificări ale Termenilor</Title>
            <Paragraph>
              Ne rezervăm dreptul de a modifica acești Termeni în orice moment. Vă vom notifica
              despre modificări prin publicarea noilor Termeni în aplicație. Continuarea utilizării
              Serviciului după publicarea modificărilor constituie acceptarea noilor Termeni.
            </Paragraph>

            <Title level={4}>12. Încetare</Title>
            <Paragraph>
              Putem înceta sau suspenda accesul dumneavoastră la Serviciu imediat, fără notificare
              prealabilă, pentru orice motiv, inclusiv, fără limitare, dacă încălcați acești Termeni.
              La încetare, dreptul dumneavoastră de a utiliza Serviciul va înceta imediat.
            </Paragraph>

            <Title level={4}>13. Legea aplicabilă</Title>
            <Paragraph>
              Acești Termeni vor fi guvernați și interpretați în conformitate cu legile României,
              fără a ține cont de prevederile privind conflictul de legi. Orice litigiu va fi
              soluționat de instanțele competente din România.
            </Paragraph>

            <Title level={4}>14. Dispoziții generale</Title>
            <Paragraph>
              <Text strong>14.1. Integralitate:</Text> Acești Termeni constituie acordul complet
              între dumneavoastră și noi privind utilizarea Serviciului.
            </Paragraph>
            <Paragraph>
              <Text strong>14.2. Renunțare:</Text> Neexercitarea unui drept prevăzut în acești
              Termeni nu constituie o renunțare la acel drept.
            </Paragraph>
            <Paragraph>
              <Text strong>14.3. Separabilitate:</Text> Dacă o prevedere a acestor Termeni este
              considerată invalidă, celelalte prevederi rămân în vigoare.
            </Paragraph>

            <Title level={4}>15. Contact</Title>
            <Paragraph>
              Pentru întrebări despre acești Termeni, vă rugăm să contactați administratorul
              sistemului.
            </Paragraph>

            <Divider />

            <Paragraph type="secondary" style={{ textAlign: 'center' }}>
              © {new Date().getFullYear()} Domistra - Sistem de Management Proprietăți
            </Paragraph>
          </Typography>
        </Card>
      </div>
    </div>
  );
};

export default TermsOfService;
