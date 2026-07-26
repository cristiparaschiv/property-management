import { InputNumber } from 'antd';

/**
 * Money/amount input with Romanian locale conventions:
 *  - comma as the decimal separator (matches how amounts are displayed),
 *  - fixed 2-decimal precision (no accidental 210,047 RON),
 *  - non-negative by default, full width.
 *
 * Works inside antd Form.Item: Form injects `value`/`onChange` as props and
 * they are spread onto the underlying InputNumber, which still emits a plain
 * numeric value to onChange.
 */
const MoneyInput = ({ precision = 2, min = 0, style, ...rest }) => (
  <InputNumber
    decimalSeparator=","
    precision={precision}
    min={min}
    step={0.01}
    style={{ width: '100%', ...style }}
    {...rest}
  />
);

export default MoneyInput;
