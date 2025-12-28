import React from 'react';
import { Button, Typography, Space, Card } from 'antd';
import {
  HomeOutlined,
  FileTextOutlined,
  CalculatorOutlined,
  CloudOutlined,
  SafetyOutlined,
  LoginOutlined,
} from '@ant-design/icons';
import { Link, useNavigate } from 'react-router-dom';
import useAuthStore from '../stores/authStore';

const { Title, Paragraph, Text } = Typography;

const Home = () => {
  const navigate = useNavigate();
  const { isAuthenticated } = useAuthStore();

  // If already logged in, redirect to dashboard
  React.useEffect(() => {
    if (isAuthenticated) {
      navigate('/', { replace: true });
    }
  }, [isAuthenticated, navigate]);

  const features = [
    {
      icon: <HomeOutlined style={{ fontSize: 32, color: '#10b981' }} />,
      title: 'Gestionare Chiriași',
      description: 'Evidența completă a chiriașilor, contractelor și plăților.',
    },
    {
      icon: <FileTextOutlined style={{ fontSize: 32, color: '#10b981' }} />,
      title: 'Facturare Automată',
      description: 'Generare automată de facturi pentru chirie și utilități.',
    },
    {
      icon: <CalculatorOutlined style={{ fontSize: 32, color: '#10b981' }} />,
      title: 'Calcul Utilități',
      description: 'Calculul automat al consumurilor pe baza citirilor de contoare.',
    },
    {
      icon: <CloudOutlined style={{ fontSize: 32, color: '#10b981' }} />,
      title: 'Backup în Cloud',
      description: 'Backup automat în Google Drive pentru siguranța datelor.',
    },
  ];

  return (
    <div
      style={{
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 50%, #10b981 100%)',
      }}
    >
      {/* Header */}
      <div
        style={{
          padding: '20px 40px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <img
            src="/assets/domistra-2-logo.png"
            alt="Domistra"
            style={{ height: 50 }}
          />
        </div>
        <Button
          type="primary"
          icon={<LoginOutlined />}
          size="large"
          onClick={() => navigate('/login')}
        >
          Autentificare
        </Button>
      </div>

      {/* Hero Section */}
      <div
        style={{
          textAlign: 'center',
          padding: '80px 20px',
          maxWidth: 800,
          margin: '0 auto',
        }}
      >
        <Title style={{ color: '#fff', fontSize: 48, marginBottom: 24 }}>
          Domistra
        </Title>
        <Title level={2} style={{ color: '#e2e8f0', fontWeight: 400, marginBottom: 32 }}>
          Sistem de Management al Proprietăților
        </Title>
        <Paragraph style={{ color: '#94a3b8', fontSize: 18, marginBottom: 40 }}>
          Soluția completă pentru administrarea proprietăților imobiliare.
          Gestionați chiriașii, facturile, utilitățile și backup-urile într-un singur loc.
        </Paragraph>
        <Button
          type="primary"
          size="large"
          icon={<LoginOutlined />}
          onClick={() => navigate('/login')}
          style={{ height: 50, paddingInline: 40, fontSize: 16 }}
        >
          Accesează Aplicația
        </Button>
      </div>

      {/* Features Section */}
      <div
        style={{
          padding: '60px 20px',
          maxWidth: 1200,
          margin: '0 auto',
        }}
      >
        <Title level={3} style={{ color: '#fff', textAlign: 'center', marginBottom: 40 }}>
          Funcționalități
        </Title>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))',
            gap: 24,
          }}
        >
          {features.map((feature, index) => (
            <Card
              key={index}
              style={{
                textAlign: 'center',
                background: 'rgba(255, 255, 255, 0.95)',
              }}
            >
              <div style={{ marginBottom: 16 }}>{feature.icon}</div>
              <Title level={4} style={{ marginBottom: 8 }}>
                {feature.title}
              </Title>
              <Text type="secondary">{feature.description}</Text>
            </Card>
          ))}
        </div>
      </div>

      {/* Security Section */}
      <div
        style={{
          padding: '60px 20px',
          maxWidth: 800,
          margin: '0 auto',
          textAlign: 'center',
        }}
      >
        <SafetyOutlined style={{ fontSize: 48, color: '#10b981', marginBottom: 16 }} />
        <Title level={3} style={{ color: '#fff', marginBottom: 16 }}>
          Securitate și Confidențialitate
        </Title>
        <Paragraph style={{ color: '#94a3b8', fontSize: 16 }}>
          Datele dumneavoastră sunt protejate prin criptare, autentificare securizată
          și backup automat în cloud. Respectăm reglementările GDPR pentru protecția
          datelor personale.
        </Paragraph>
      </div>

      {/* Footer */}
      <div
        style={{
          padding: '40px 20px',
          textAlign: 'center',
          borderTop: '1px solid rgba(255, 255, 255, 0.1)',
        }}
      >
        <Space split={<span style={{ color: '#475569' }}>|</span>} size="middle">
          <Link to="/privacy-policy" style={{ color: '#94a3b8' }}>
            Politica de Confidențialitate
          </Link>
          <Link to="/terms-of-service" style={{ color: '#94a3b8' }}>
            Termeni și Condiții
          </Link>
        </Space>
        <Paragraph style={{ color: '#64748b', marginTop: 16, marginBottom: 0 }}>
          © {new Date().getFullYear()} Domistra - Sistem de Management Proprietăți
        </Paragraph>
      </div>
    </div>
  );
};

export default Home;
