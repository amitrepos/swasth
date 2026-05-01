import React from 'react';
import './DashboardMockup.css';

const DashboardMockup: React.FC = () => {
  return (
    <div className="swasth-mockup-wrap">
      <div className="mockup-content">
        <div className="top-bar">
          <div>
            <div className="brand">SWASTH</div>
            <div className="greeting">Good evening,</div>
            <div className="user-name">⚕ Deep ↗</div>
          </div>
          <div className="top-icons">
            <span>📋</span><span>↗</span>
            <div className="avatar">D</div>
            <span>⏻</span>
          </div>
        </div>

        <div className="badges">
          <div className="badge">🇮🇳 ENGLISH</div>
          <div className="badge">🔥 2 DAYS</div>
          <div className="badge">🏆 10 PTS</div>
        </div>

        <div className="health-card">
          <div className="doing-great">You're doing great</div>

          <div className="heart-container">
            <div className="pulse-ring"></div>
            <div className="pulse-ring pulse-ring-2"></div>

            <svg className="heart-svg" viewBox="0 0 100 90" xmlns="http://www.w3.org/2000/svg">
              <defs>
                <radialGradient id="hg" cx="50%" cy="40%" r="60%">
                  <stop offset="0%" stopColor="#4caf50"/>
                  <stop offset="100%" stopColor="#1b5e20"/>
                </radialGradient>
              </defs>
              <path d="M50 80 C50 80 10 52 10 28 C10 14 20 6 32 8 C40 9 47 15 50 20 C53 15 60 9 68 8 C80 6 90 14 90 28 C90 52 50 80 50 80 Z"
                fill="url(#hg)" />
              <path d="M50 78 C50 78 12 52 12 29 C12 16 21 9 32 10 C40 11 47 17 50 22"
                fill="none" stroke="rgba(255,255,255,0.15)" strokeWidth="2" strokeLinecap="round"/>
            </svg>

            <div className="heart-score">80</div>
          </div>

          <div className="all-well"><span className="smiley">😊</span> All is well</div>
          <div className="progress-bar-bg"><div className="progress-bar-fill"></div></div>
          <div className="health-msg">All readings look healthy today. You're doing great!</div>
        </div>

        <div className="section-title">VITALS</div>
        <div className="vitals-grid">
          <div className="vital-card">
            <div className="vital-label">LAST BP</div>
            <div className="vital-row">
              <div><div className="vital-value">130/80</div></div>
              <div className="add-btn">+</div>
            </div>
          </div>
          <div className="vital-card">
            <div className="vital-label">LAST SUGAR</div>
            <div className="vital-row">
              <div><div className="vital-value">109 mg</div></div>
              <div className="add-btn">+</div>
            </div>
          </div>
          <div className="vital-card">
            <div className="vital-label">WEIGHT</div>
            <div className="vital-row">
              <div><div className="vital-value" style={{ color: '#333' }}>72.0 kg</div></div>
              <div className="add-btn">+</div>
            </div>
          </div>
          <div className="vital-card">
            <div className="vital-label">BMI</div>
            <div className="vital-row">
              <div>
                <div className="bmi-label">Overweight</div>
                <div className="vital-value orange">25.5</div>
                <div className="vital-footer">Lose 1.7 kg</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="bottom-nav">
        <div className="nav-item active">
          <div className="nav-icon">🏠</div>
          <div className="nav-label">HOME</div>
        </div>
        <div className="nav-item">
          <div className="nav-icon">📊</div>
          <div className="nav-label">HISTORY</div>
        </div>
        <div className="nav-item">
          <div className="streak-nav">🔥</div>
          <div className="nav-label" style={{ marginTop: '4px' }}>STREAKS</div>
        </div>
        <div className="nav-item">
          <div className="nav-icon">📈</div>
          <div className="nav-label">INSIGHTS</div>
        </div>
        <div className="nav-item">
          <div className="nav-icon">💬</div>
          <div className="nav-label">CHAT</div>
        </div>
      </div>
    </div>
  );
};

export default DashboardMockup;
