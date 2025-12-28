import React from 'react';
import { Typography, Card, Divider, Button } from 'antd';
import { ArrowLeftOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';

const { Title, Paragraph, Text } = Typography;

const PrivacyPolicy = () => {
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
            <Title level={2}>Politica de Confidențialitate</Title>
            <Text type="secondary">Ultima actualizare: {new Date().toLocaleDateString('ro-RO')}</Text>

            <Divider />

            <Title level={4}>1. Introducere</Title>
            <Paragraph>
              Domistra („noi", „nouă" sau „aplicația") este un sistem de management al proprietăților
              care vă ajută să gestionați chiriașii, facturile și utilitățile. Această Politică de
              Confidențialitate explică modul în care colectăm, utilizăm și protejăm informațiile
              dumneavoastră personale.
            </Paragraph>

            <Title level={4}>2. Informațiile pe care le colectăm</Title>
            <Paragraph>
              Colectăm următoarele tipuri de informații:
            </Paragraph>
            <Paragraph>
              <Text strong>2.1. Informații furnizate direct de dumneavoastră:</Text>
              <ul>
                <li>Date de autentificare (nume de utilizator, parolă criptată)</li>
                <li>Informații despre companie (nume, CUI, adresă, date bancare)</li>
                <li>Date despre chiriași (nume, email, telefon, adresă)</li>
                <li>Informații despre facturi și plăți</li>
                <li>Date despre contoare și consumuri de utilități</li>
              </ul>
            </Paragraph>
            <Paragraph>
              <Text strong>2.2. Informații colectate automat:</Text>
              <ul>
                <li>Adresa IP și informații despre browser</li>
                <li>Jurnale de activitate în aplicație</li>
                <li>Date despre sesiuni de autentificare</li>
              </ul>
            </Paragraph>
            <Paragraph>
              <Text strong>2.3. Informații de la servicii terțe:</Text>
              <ul>
                <li>Adresa de email Google (când conectați Google Drive pentru backup)</li>
                <li>Cursuri de schimb valutar de la Banca Națională a României</li>
              </ul>
            </Paragraph>

            <Title level={4}>3. Cum utilizăm informațiile</Title>
            <Paragraph>
              Utilizăm informațiile colectate pentru:
              <ul>
                <li>Furnizarea și îmbunătățirea serviciilor noastre</li>
                <li>Gestionarea contului dumneavoastră și autentificarea</li>
                <li>Generarea facturilor și rapoartelor</li>
                <li>Crearea și stocarea backup-urilor în Google Drive</li>
                <li>Calcularea consumurilor de utilități</li>
                <li>Trimiterea notificărilor despre facturi scadente</li>
                <li>Asigurarea securității aplicației</li>
              </ul>
            </Paragraph>

            <Title level={4}>4. Integrarea cu Google Drive</Title>
            <Paragraph>
              Aplicația oferă posibilitatea de a vă conecta contul Google pentru a stoca backup-uri
              ale bazei de date în Google Drive. Când utilizați această funcționalitate:
              <ul>
                <li>Accesăm doar folderul „Domistra Backups" creat de aplicație</li>
                <li>Stocăm token-urile de acces în mod securizat</li>
                <li>Nu accesăm alte fișiere din Google Drive</li>
                <li>Puteți revoca accesul oricând din setările aplicației sau din contul Google</li>
              </ul>
            </Paragraph>

            <Title level={4}>5. Partajarea informațiilor</Title>
            <Paragraph>
              Nu vindem, nu închiriem și nu partajăm informațiile dumneavoastră personale cu terți,
              cu excepția:
              <ul>
                <li>Google LLC - pentru funcționalitatea de backup în Google Drive (doar cu acordul explicit)</li>
                <li>Banca Națională a României - accesăm public cursurile de schimb valutar</li>
                <li>Autorități legale - când suntem obligați prin lege</li>
              </ul>
            </Paragraph>

            <Title level={4}>6. Securitatea datelor</Title>
            <Paragraph>
              Implementăm măsuri tehnice și organizatorice pentru a proteja datele dumneavoastră:
              <ul>
                <li>Criptarea parolelor folosind algoritmi securizați</li>
                <li>Conexiuni HTTPS pentru toate transmisiile de date</li>
                <li>Token-uri JWT pentru autentificare securizată</li>
                <li>Protecție CSRF pentru toate operațiunile sensibile</li>
                <li>Rate limiting pentru prevenirea atacurilor</li>
                <li>Backup-uri criptate în Google Drive</li>
              </ul>
            </Paragraph>

            <Title level={4}>7. Păstrarea datelor</Title>
            <Paragraph>
              Păstrăm datele dumneavoastră atât timp cât contul este activ. După ștergerea contului,
              datele vor fi eliminate din sistemele noastre în termen de 30 de zile, cu excepția
              backup-urilor din Google Drive pe care le controlați direct.
            </Paragraph>

            <Title level={4}>8. Drepturile dumneavoastră</Title>
            <Paragraph>
              Conform GDPR, aveți următoarele drepturi:
              <ul>
                <li><Text strong>Dreptul de acces</Text> - puteți solicita o copie a datelor dumneavoastră</li>
                <li><Text strong>Dreptul la rectificare</Text> - puteți corecta datele inexacte</li>
                <li><Text strong>Dreptul la ștergere</Text> - puteți solicita ștergerea datelor</li>
                <li><Text strong>Dreptul la portabilitate</Text> - puteți exporta datele într-un format standard</li>
                <li><Text strong>Dreptul de opoziție</Text> - puteți refuza prelucrarea în anumite scopuri</li>
                <li><Text strong>Dreptul de retragere a consimțământului</Text> - în orice moment</li>
              </ul>
            </Paragraph>

            <Title level={4}>9. Cookie-uri</Title>
            <Paragraph>
              Aplicația utilizează cookie-uri strict necesare pentru:
              <ul>
                <li>Menținerea sesiunii de autentificare</li>
                <li>Stocarea preferințelor de temă (mod întunecat/luminos)</li>
                <li>Protecția CSRF</li>
              </ul>
              Nu utilizăm cookie-uri de tracking sau publicitate.
            </Paragraph>

            <Title level={4}>10. Modificări ale politicii</Title>
            <Paragraph>
              Ne rezervăm dreptul de a actualiza această politică. Vă vom notifica despre modificări
              semnificative prin intermediul aplicației sau prin email.
            </Paragraph>

            <Title level={4}>11. Contact</Title>
            <Paragraph>
              Pentru întrebări sau solicitări privind datele dumneavoastră personale, ne puteți
              contacta la adresa de email a administratorului sistemului.
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

export default PrivacyPolicy;
