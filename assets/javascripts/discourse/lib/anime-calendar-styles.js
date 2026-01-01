// Critical inline styles for calendar - embedded directly in component
export default function applyCalendarStyles() {
    const styleId = 'anime-calendar-critical-styles';

    // Remove existing if present
    const existing = document.getElementById(styleId);
    if (existing) existing.remove();

    // Create style element
    const style = document.createElement('style');
    style.id = styleId;
    style.textContent = `
    /* Critical Calendar Styles */
    .anime-calendar-container {
      padding: 30px 20px;
      max-width: 1600px;
      margin: 0 auto;
    }
    
    .anime-grid.grid-view {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(600px, 1fr));
      gap: 30px;
      margin-top: 20px;
    }
    
    @media (max-width: 1400px) {
      .anime-grid.grid-view {
        grid-template-columns: repeat(auto-fill, minmax(500px, 1fr));
      }
    }
    
    @media (max-width: 1100px) {
      .anime-grid.grid-view {
        grid-template-columns: 1fr;
      }
    }
    
    .anime-card-livechart {
      background: var(--secondary);
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
      border: 1px solid var(--primary-low);
      transition: all 0.3s ease;
    }
    
    .anime-card-livechart:hover {
      transform: translateY(-4px);
      box-shadow: 0 8px 20px rgba(0, 0, 0, 0.12);
    }
    
    .anime-card-livechart .card-link {
      display: grid;
      grid-template-columns: 240px 1fr;
      text-decoration: none;
      color: inherit;
    }
    
    @media (max-width: 768px) {
      .anime-card-livechart .card-link {
        grid-template-columns: 1fr;
      }
    }
    
    .card-poster-section {
      position: relative;
      aspect-ratio: 2/3;
      overflow: hidden;
      background: var(--primary-very-low);
    }
    
    @media (max-width: 768px) {
      .card-poster-section {
        aspect-ratio: 16/9;
      }
    }
    
    .card-poster-section img {
      width: 100%;
      height: 100%;
      object-fit: cover;
      transition: transform 0.4s ease;
    }
    
    .anime-card-livechart:hover .card-poster-section img {
      transform: scale(1.05);
    }
    
    .countdown-badge {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      background: rgba(0, 0, 0, 0.85);
      color: white;
      padding: 10px 12px;
      font-weight: 700;
      font-size: 0.9rem;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    
    .countdown-badge.airing {
      background: rgba(26, 188, 156, 0.9);
    }
    
    .card-info-section {
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    
    .anime-title {
      font-size: 1.3rem;
      font-weight: 700;
      color: #0076A3;
      margin: 0 0 6px 0;
      line-height: 1.3;
    }
    
    .anime-genres-subtle {
      display: flex;
      flex-wrap: wrap;
      gap: 6px;
      margin-bottom: 4px;
    }
    
    .genre-pill {
      font-size: 0.75rem;
      background: var(--primary-very-low);
      color: var(--primary-medium);
      padding: 3px 10px;
      border-radius: 12px;
      font-weight: 500;
    }
    
    .anime-metadata {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
      gap: 10px;
      margin: 8px 0;
      font-size: 0.85rem;
    }
    
    .meta-label {
      color: var(--primary-medium);
      font-weight: 500;
      margin-right: 4px;
    }
    
    .meta-value {
      font-weight: 600;
      color: var(--primary);
    }
    
    .meta-value.studio-name {
      color: #0076A3;
   }
    
    .anime-synopsis {
      font-size: 0.9rem;
      line-height: 1.6;
      color: var(--primary-high);
      margin: 6px 0;
      display: -webkit-box;
      -webkit-line-clamp: 3;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }
    
    .anime-external-links {
      display: flex;
      gap: 12px;
      margin-top: auto;
      padding-top: 12px;
      border-top: 1px solid var(--primary-low);
    }
    
    .external-link {
      display: flex;
      align-items: center;
      gap: 4px;
      padding: 4px 10px;
      background: var(--primary-very-low);
      border-radius: 6px;
      color: var(--primary-high);
      text-decoration: none;
      font-size: 0.8rem;
      font-weight: 600;
      transition: all 0.2s ease;
    }
    
    .external-link:hover {
      background: #0076A3;
      color: white;
      transform: translateY(-2px);
    }
    
    .calendar-header {
      margin-bottom: 30px;
    }
    
    .calendar-header h1 {
      font-size: 2.4rem;
      font-weight: 800;
      margin: 0 0 10px 0;
    }
    
    .calendar-controls {
      display: flex;
      flex-wrap: wrap;
      align-items: center;
      gap: 15px;
      padding: 20px;
      background: var(--secondary);
      border-radius: 12px;
      border: 1px solid var(--primary-low);
      margin-top: 20px;
    }
    
    .control-group {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    
    .sort-select {
      padding: 8px 12px;
      border: 1px solid var(--primary-low);
      border-radius: 6px;
      background: var(--primary-very-low);
      color: var(--primary);
    }
    
    .btn-watchlist-filter {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 8px 16px;
      background: transparent;
      border: 2px solid var(--primary-low);
      border-radius: 20px;
      color: var(--primary-high);
      font-weight: 600;
      cursor: pointer;
    }
    
    .btn-watchlist-filter.active {
      background: var(--love);
      border-color: var(--love);
      color: white;
    }
  `;

    document.head.appendChild(style);
}
