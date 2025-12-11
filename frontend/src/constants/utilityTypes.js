// Utility type mappings for the application
export const UTILITY_TYPE_OPTIONS = [
  { value: 'electricity', label: 'Electricitate' },
  { value: 'gas', label: 'Gaze' },
  { value: 'water', label: 'Apă' },
  { value: 'internet', label: 'Internet' },
  { value: 'salubrity', label: 'Salubritate' },
  { value: 'other', label: 'Altele' },
];

// Mapping object for quick label lookups
export const UTILITY_TYPE_LABELS = {
  electricity: 'Electricitate',
  gas: 'Gaze',
  water: 'Apă',
  internet: 'Internet',
  salubrity: 'Salubritate',
  other: 'Altele',
};

// Helper function to get the Romanian label for a utility type
export const getUtilityTypeLabel = (type) => {
  return UTILITY_TYPE_LABELS[type] || type;
};
