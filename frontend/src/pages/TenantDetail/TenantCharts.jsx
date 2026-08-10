import { Row, Col, Card, Empty, Tag } from 'antd';
import {
  ResponsiveContainer, ScatterChart, Scatter, XAxis, YAxis, CartesianGrid, Tooltip,
  BarChart, Bar, LineChart, Line, Legend,
} from 'recharts';
import { formatCurrency } from '../../utils/formatters';

const UTIL_LABEL = {
  electricity: 'Electricitate', gas: 'Gaz', water: 'Apă',
  salubrity: 'Salubritate', internet: 'Internet', other: 'Altele',
};

const CardBox = ({ title, children }) => (
  <Card size="small" title={title} style={{ height: '100%' }}>{children}</Card>
);

const TenantCharts = ({ overview }) => {
  const { payment_behaviour = [], utility_allocation = [], metered_consumption = {}, data_completeness = {} } = overview;

  const alloc = utility_allocation.map((u) => ({
    name: UTIL_LABEL[u.utility_type] || u.utility_type, total: Number(u.total_ron),
  }));

  // Merge metered series into rows keyed by period, so gaps stay as missing points.
  const utils = Object.keys(metered_consumption);
  const periodSet = new Set();
  utils.forEach((u) => metered_consumption[u].forEach((p) => periodSet.add(p.period)));
  const periods = [...periodSet].sort();
  const consRows = periods.map((period) => {
    const row = { period };
    utils.forEach((u) => {
      const pt = metered_consumption[u].find((p) => p.period === period);
      row[u] = pt ? pt.value : null; // null = gap, never 0
    });
    return row;
  });
  const lineColors = { electricity: '#b8860b', gas: '#d97706', water: '#2563eb' };

  return (
    <Row gutter={[16, 16]}>
      <Col xs={24} lg={12}>
        <CardBox title="Comportament de plată (zile până la plată)">
          {payment_behaviour.length === 0 ? (
            <Empty description="Nicio factură plătită" />
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <ScatterChart margin={{ top: 10, right: 20, bottom: 10, left: 0 }}>
                <CartesianGrid />
                <XAxis dataKey="invoice_date" name="Emisă" tick={{ fontSize: 11 }} />
                <YAxis dataKey="days_to_pay" name="Zile" tick={{ fontSize: 11 }} />
                <Tooltip cursor={{ strokeDasharray: '3 3' }} />
                <Scatter data={payment_behaviour} fill="#b8860b" />
              </ScatterChart>
            </ResponsiveContainer>
          )}
        </CardBox>
      </Col>

      <Col xs={24} lg={12}>
        <CardBox title="Alocare utilități (RON)">
          {alloc.length === 0 ? (
            <Empty description="Fără alocări finalizate" />
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <BarChart data={alloc} layout="vertical" margin={{ left: 20, right: 30 }}>
                <CartesianGrid horizontal={false} />
                <XAxis type="number" tick={{ fontSize: 11 }} />
                <YAxis type="category" dataKey="name" width={90} tick={{ fontSize: 11 }} />
                <Tooltip formatter={(v) => formatCurrency(v)} />
                <Bar dataKey="total" fill="#b8860b" />
              </BarChart>
            </ResponsiveContainer>
          )}
        </CardBox>
      </Col>

      <Col xs={24} lg={12}>
        <CardBox title="Consum contorizat">
          {utils.length === 0 ? (
            <Empty description="Chiriaș necontorizat" />
          ) : (
            <ResponsiveContainer width="100%" height={240}>
              <LineChart data={consRows} margin={{ top: 10, right: 20, left: 0 }}>
                <CartesianGrid />
                <XAxis dataKey="period" tick={{ fontSize: 11 }} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip />
                <Legend />
                {utils.map((u) => (
                  <Line key={u} type="monotone" dataKey={u} name={UTIL_LABEL[u] || u}
                    stroke={lineColors[u] || '#888'} connectNulls={false} dot />
                ))}
              </LineChart>
            </ResponsiveContainer>
          )}
        </CardBox>
      </Col>

      <Col xs={24} lg={12}>
        <CardBox title="Completitudine date">
          <div style={{ marginBottom: 8, color: 'var(--pm-color-text-secondary)' }}>Necompletate</div>
          <div style={{ marginBottom: 12 }}>
            {(data_completeness.empty_fields || []).length === 0
              ? <Tag color="green">Complet</Tag>
              : (data_completeness.empty_fields || []).map((f) => <Tag key={f}>{f}</Tag>)}
          </div>
          <div style={{ marginBottom: 8, color: 'var(--pm-color-text-secondary)' }}>Nemodelate în sistem</div>
          <div>{(data_completeness.not_modelled || []).map((f) => <Tag key={f} color="default">{f}</Tag>)}</div>
        </CardBox>
      </Col>
    </Row>
  );
};

export default TenantCharts;
