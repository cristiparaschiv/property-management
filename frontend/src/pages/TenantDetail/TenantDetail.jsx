import { useParams, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { Spin, Result, Button, Card, Descriptions, Row, Col, Statistic, Tag, Tabs } from 'antd';
import { ArrowLeftOutlined, EditOutlined } from '@ant-design/icons';
import { tenantsService } from '../../services/tenantsService';
import { formatCurrency } from '../../utils/formatters';
import TenantCharts from './TenantCharts';

const TenantDetail = () => {
  const { id } = useParams();
  const navigate = useNavigate();

  const { data, isLoading, isError } = useQuery({
    queryKey: ['tenant-overview', id],
    queryFn: () => tenantsService.getOverview(id),
    enabled: !!id,
  });

  if (isLoading) return <Spin style={{ display: 'block', margin: '80px auto' }} />;
  if (isError || !data?.data) {
    return (
      <Result
        status="404"
        title="Chiriaș negăsit"
        extra={<Button onClick={() => navigate('/tenants')}>Înapoi la chiriași</Button>}
      />
    );
  }

  const { tenant, kpis } = data.data;

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
        <Button icon={<ArrowLeftOutlined />} onClick={() => navigate('/tenants')} />
        <h1 style={{ margin: 0, flex: 1 }}>{tenant.name}</h1>
        <Tag color={tenant.is_active ? 'green' : 'default'}>
          {tenant.is_active ? 'Activ' : 'Inactiv'}
        </Tag>
        <Button icon={<EditOutlined />} onClick={() => navigate('/tenants')}>
          Editează
        </Button>
      </div>

      <Card style={{ marginBottom: 16 }}>
        <Descriptions column={{ xs: 1, sm: 2, md: 3 }} size="small">
          <Descriptions.Item label="CUI/CNP">{tenant.cui_cnp || '—'}</Descriptions.Item>
          <Descriptions.Item label="Nr. Reg. Com.">{tenant.j_number || '—'}</Descriptions.Item>
          <Descriptions.Item label="Adresă">
            {[tenant.address, tenant.city, tenant.county].filter(Boolean).join(', ') || '—'}
          </Descriptions.Item>
          <Descriptions.Item label="Telefon">{tenant.phone || '—'}</Descriptions.Item>
          <Descriptions.Item label="Email">{tenant.email || '—'}</Descriptions.Item>
          <Descriptions.Item label="Chirie">
            {tenant.rent_amount_eur ? `${tenant.rent_amount_eur} EUR` : '—'}
          </Descriptions.Item>
        </Descriptions>
      </Card>

      <Row gutter={[16, 16]} style={{ marginBottom: 16 }}>
        <Col xs={12} md={8} lg={4}>
          <Card size="small"><Statistic title="Facturat" value={formatCurrency(kpis.billed_ron)} /></Card>
        </Col>
        <Col xs={12} md={8} lg={4}>
          <Card size="small"><Statistic title="Încasat" value={formatCurrency(kpis.paid_ron)} /></Card>
        </Col>
        <Col xs={12} md={8} lg={4}>
          <Card size="small">
            <Statistic title={`De încasat (${kpis.open_count})`} value={formatCurrency(kpis.outstanding_ron)} />
          </Card>
        </Col>
        <Col xs={12} md={8} lg={4}>
          <Card size="small">
            <Statistic title="Cea mai veche neplătită"
              value={kpis.oldest_unpaid_days != null ? `${kpis.oldest_unpaid_days} zile` : '—'} />
          </Card>
        </Col>
        <Col xs={12} md={8} lg={4}>
          <Card size="small">
            <Statistic title="Media zile până la plată"
              value={kpis.avg_days_to_pay != null ? `${kpis.avg_days_to_pay} zile` : '—'} />
          </Card>
        </Col>
      </Row>

      <TenantCharts overview={data.data} />

      <Tabs
        style={{ marginTop: 16 }}
        items={[
          { key: 'invoices', label: 'Facturi', children: <div /> },
          { key: 'statement', label: 'Fișă cont', children: <div /> },
        ]}
      />
    </div>
  );
};

export default TenantDetail;
