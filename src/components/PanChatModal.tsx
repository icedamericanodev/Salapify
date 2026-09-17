import React, { useState, useRef, useEffect, useMemo } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import {
  X,
  Send,
  Sparkles,
  Bot,
  RotateCcw,
  ShieldCheck,
  ArrowRight,
  TrendingUp,
  Wallet,
  Receipt,
  HelpCircle,
  Copy,
  Check,
  ShieldAlert,
  CheckCircle2,
  AlertTriangle,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { processPanQuery, PanResponse, PanContext } from '../utils/panAiEngine';
import { formatPeso } from '../utils/format';

interface PanChatModalProps {
  isOpen: boolean;
  onClose: () => void;
  onNavigateTo?: (actionId: string, payload?: any) => void;
  initialQuery?: string;
}

interface ChatMessage {
  id: string;
  sender: 'user' | 'pan';
  text: string;
  timestamp: string;
  response?: PanResponse;
}

const QUICK_STARTERS = [
  'Can I afford ₱2,500?',
  'Audit my finances',
  'Where can I see the offline registry?',
  'Safe to Spend today?',
  'Who owes me money?',
  'Which credit cards are due soon?',
  'What was my biggest expense?',
  'How to start an app business in PH?',
  'Where should I keep my emergency fund?',
  '13th-Month tax exemption rule',
];

export const PanChatModal: React.FC<PanChatModalProps> = ({
  isOpen,
  onClose,
  onNavigateTo,
  initialQuery,
}) => {
  const financial = useFinancial();
  const [inputValue, setInputValue] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [lastTopic, setLastTopic] = useState<string | undefined>(undefined);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const sentInitialQueryRef = useRef<string | null>(null);

  // Construct current real-time context
  const panContext: PanContext = useMemo(
    () => ({
      accounts: financial.accounts,
      debts: financial.debts,
      transactions: financial.transactions,
      bills: financial.bills,
      installments: financial.installments,
      goals: financial.goals,
      payday: financial.payday,
      safeToSpend: financial.safeToSpend,
      safeToSpendPerDay: financial.safeToSpendPerDay,
      totalAssets: financial.totalAssets,
      totalLiabilities: financial.totalLiabilities,
      netWorth: financial.netWorth,
      totalDebtsIOwe: financial.totalDebtsIOwe,
      totalDebtsOwedToMe: financial.totalDebtsOwedToMe,
      totalCreditUsed: financial.totalCreditUsed,
      lastTopic,
    }),
    [
      financial.accounts,
      financial.debts,
      financial.transactions,
      financial.bills,
      financial.installments,
      financial.goals,
      financial.payday,
      financial.safeToSpend,
      financial.safeToSpendPerDay,
      financial.totalAssets,
      financial.totalLiabilities,
      financial.netWorth,
      financial.totalDebtsIOwe,
      financial.totalDebtsOwedToMe,
      financial.totalCreditUsed,
      lastTopic,
    ]
  );

  // Initial welcome message from Pan
  const initialGreeting = useMemo<ChatMessage>(() => {
    return {
      id: 'greeting',
      sender: 'pan',
      text: `Kumusta! I am **Pan**, your private on-device financial copilot.\n\nRight now you have **${formatPeso(
        financial.safeToSpend
      )}** safe to spend (${formatPeso(financial.safeToSpendPerDay)}/day until your next payday on ${
        financial.payday.nextPayday.split(',')[0]
      }).\n\nAsk me anything about your balances, credit cards, bills, split-debts, or Philippine tax rules!`,
      timestamp: 'Just now',
      response: {
        text: '',
        badge: 'Pan Copilot',
        stats: [
          { label: 'Safe Balance', value: formatPeso(financial.safeToSpend), color: '#16643F' },
          { label: 'Daily Pace', value: `${formatPeso(financial.safeToSpendPerDay)}/day` },
          { label: 'Accounts', value: `${financial.accounts.length} linked` },
        ],
        actions: [
          { label: 'Safe to Spend Details', actionId: 'open_safe_to_spend' },
          { label: 'Check Upcoming Bills', actionId: 'open_bills' },
        ],
        suggestedFollowUps: [
          'Safe to Spend today?',
          'Who owes me money?',
          'Which credit cards are due soon?',
        ],
      },
    };
  }, [
    financial.safeToSpend,
    financial.safeToSpendPerDay,
    financial.payday.nextPayday,
    financial.accounts.length,
  ]);

  const [messages, setMessages] = useState<ChatMessage[]>([initialGreeting]);

  // Auto-send initial query if modal is opened with one
  useEffect(() => {
    if (isOpen && initialQuery && initialQuery !== sentInitialQueryRef.current) {
      sentInitialQueryRef.current = initialQuery;
      handleSendMessage(initialQuery);
    }
  }, [isOpen, initialQuery]);

  // Scroll to bottom when messages update
  useEffect(() => {
    if (isOpen) {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages, isOpen, isTyping]);

  const handleSendMessage = (textToSend?: string) => {
    const text = (textToSend || inputValue).trim();
    if (!text) return;

    const userMsg: ChatMessage = {
      id: String(Date.now()),
      sender: 'user',
      text,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    };

    setMessages((prev) => [...prev, userMsg]);
    if (!textToSend) setInputValue('');
    setIsTyping(true);

    // Simulate realistic 200ms thinking time for smooth conversational feel
    setTimeout(() => {
      const response = processPanQuery(text, panContext);
      if (response.badge) {
        setLastTopic(response.badge);
      }
      const panMsg: ChatMessage = {
        id: String(Date.now() + 1),
        sender: 'pan',
        text: response.text,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        response,
      };
      setMessages((prev) => [...prev, panMsg]);
      setIsTyping(false);
    }, 240);
  };

  const handleCopyMessage = (id: string, text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 1800);
  };

  const handleResetChat = () => {
    setLastTopic(undefined);
    setMessages([initialGreeting]);
  };

  const handleActionClick = (actionId: string, payload?: any) => {
    onClose();
    if (onNavigateTo) {
      onNavigateTo(actionId, payload);
    }
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/50 backdrop-blur-xs">
        <motion.div
          initial={{ opacity: 0, y: 100 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: 100 }}
          transition={{ duration: 0.25, ease: 'easeOut' }}
          className="w-full max-w-lg bg-[#FFEEDF] dark:bg-[#14100D] border-t sm:border border-[#F3DFCD] dark:border-[#383029] sm:rounded-3xl rounded-t-3xl shadow-2xl flex flex-col h-[88vh] sm:h-[82vh] max-h-[750px] overflow-hidden"
        >
          {/* Header */}
          <div className="px-4 py-3 bg-white/90 dark:bg-[#1E1915]/90 border-b border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between gap-2 shrink-0">
            <div className="flex items-center gap-2.5">
              <div className="w-9 h-9 rounded-2xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] flex items-center justify-center shadow-xs">
                <Bot size={20} strokeWidth={2.4} />
              </div>
              <div>
                <div className="flex items-center gap-1.5">
                  <h2 className="text-sm font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                    Pan Copilot
                  </h2>
                  <span className="px-1.5 py-0.2 rounded-full text-[9px] font-bold bg-[#16643F]/10 dark:bg-[#5FCB8E]/15 text-[#16643F] dark:text-[#5FCB8E] flex items-center gap-0.5">
                    <ShieldCheck size={10} /> 100% Private
                  </span>
                </div>
                <p className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                  On-device financial assistant for Salapify
                </p>
              </div>
            </div>

            <div className="flex items-center gap-1">
              <button
                type="button"
                onClick={handleResetChat}
                title="Restart chat"
                className="p-2 rounded-xl text-[#6B6156] dark:text-[#AC9E92] hover:bg-[#FFEEDF] dark:hover:bg-[#2A221C] transition-colors cursor-pointer"
                aria-label="Restart chat"
              >
                <RotateCcw size={16} />
              </button>
              <button
                type="button"
                onClick={onClose}
                title="Close Pan"
                className="p-2 rounded-xl text-[#6B6156] dark:text-[#AC9E92] hover:bg-[#FFEEDF] dark:hover:bg-[#2A221C] transition-colors cursor-pointer"
                aria-label="Close"
              >
                <X size={18} />
              </button>
            </div>
          </div>

          {/* Quick Starters Bar */}
          <div className="px-3 py-2 bg-[#FBF2EA]/70 dark:bg-[#1A1512]/70 border-b border-[#F3DFCD]/80 dark:border-[#383029]/80 overflow-x-auto no-scrollbar shrink-0">
            <div className="flex items-center gap-1.5 whitespace-nowrap">
              <span className="text-[10px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92] shrink-0 mr-1 flex items-center gap-1">
                <Sparkles size={11} className="text-[#B03C09] dark:text-[#FF9A52]" />
                Ask Pan:
              </span>
              {QUICK_STARTERS.map((prompt, idx) => (
                <button
                  key={idx}
                  type="button"
                  onClick={() => handleSendMessage(prompt)}
                  className="px-2.5 py-1 rounded-xl text-xs font-semibold bg-white dark:bg-[#27201A] hover:bg-[#B03C09] hover:text-white dark:hover:bg-[#FF9A52] dark:hover:text-[#1E0E03] text-[#5A5148] dark:text-[#C6B8AC] border border-[#F3DFCD] dark:border-[#383029] transition-all cursor-pointer shrink-0 shadow-2xs active:scale-95"
                >
                  {prompt}
                </button>
              ))}
            </div>
          </div>

          {/* Chat Messages Container */}
          <div className="flex-1 overflow-y-auto p-4 space-y-4">
            {messages.map((msg) => {
              const isUser = msg.sender === 'user';
              return (
                <div
                  key={msg.id}
                  className={`flex flex-col ${isUser ? 'items-end' : 'items-start'}`}
                >
                  <div className="flex items-center justify-between w-full max-w-[92%] sm:max-w-[85%] mb-1 px-1">
                    <div className="flex items-center gap-1.5">
                      <span className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92]">
                        {isUser ? 'You' : 'Pan'}
                      </span>
                      <span className="text-[9px] text-[#6B6156]/70 dark:text-[#AC9E92]/70">
                        {msg.timestamp}
                      </span>
                    </div>

                    {!isUser && (
                      <button
                        type="button"
                        onClick={() => handleCopyMessage(msg.id, msg.text)}
                        className="opacity-60 hover:opacity-100 transition-opacity p-0.5 rounded text-[#6B6156] dark:text-[#AC9E92] cursor-pointer"
                        title="Copy message"
                      >
                        {copiedId === msg.id ? (
                          <span className="flex items-center gap-0.5 text-[9px] text-[#16643F] dark:text-[#5FCB8E] font-bold">
                            <Check size={11} /> Copied
                          </span>
                        ) : (
                          <Copy size={11} />
                        )}
                      </button>
                    )}
                  </div>

                  <div
                    className={`max-w-[92%] sm:max-w-[85%] rounded-2xl p-3.5 shadow-2xs text-xs leading-relaxed ${
                      isUser
                        ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#1E0E03] rounded-tr-xs font-medium'
                        : 'bg-white dark:bg-[#1E1915] text-[#15120F] dark:text-[#F6EFE8] border border-[#F3DFCD] dark:border-[#383029] rounded-tl-xs space-y-3'
                    }`}
                  >
                    {/* Badge & Affordability Indicator */}
                    {!isUser && (
                      <div className="space-y-2">
                        {msg.response?.badge && (
                          <div className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold bg-[#FFEEDF] dark:bg-[#2A221C] text-[#B03C09] dark:text-[#FF9A52]">
                            <Sparkles size={10} />
                            <span>{msg.response.badge}</span>
                          </div>
                        )}

                        {msg.response?.affordabilityStatus && (
                          <div
                            className={`px-2.5 py-1.5 rounded-xl flex items-center gap-2 text-[11px] font-bold ${
                              msg.response.affordabilityStatus === 'safe'
                                ? 'bg-[#16643F]/10 text-[#16643F] dark:bg-[#5FCB8E]/15 dark:text-[#5FCB8E] border border-[#16643F]/20'
                                : msg.response.affordabilityStatus === 'caution'
                                ? 'bg-[#D97706]/10 text-[#D97706] dark:bg-[#F59E0B]/15 dark:text-[#F59E0B] border border-[#D97706]/20'
                                : 'bg-[#B03C09]/10 text-[#B03C09] dark:bg-[#FF9A52]/15 dark:text-[#FF9A52] border border-[#B03C09]/20'
                            }`}
                          >
                            {msg.response.affordabilityStatus === 'safe' && <CheckCircle2 size={14} />}
                            {msg.response.affordabilityStatus === 'caution' && <AlertTriangle size={14} />}
                            {msg.response.affordabilityStatus === 'warning' && <ShieldAlert size={14} />}
                            <span>
                              {msg.response.affordabilityStatus === 'safe'
                                ? 'Guilt-Free: Fits your Sweldo Rail'
                                : msg.response.affordabilityStatus === 'caution'
                                ? 'Caution: Tight daily allowance until payday'
                                : 'Petsa de Peligro: Exceeds safe spending buffer'}
                            </span>
                          </div>
                        )}
                      </div>
                    )}

                    {/* Message Body */}
                    <div className="whitespace-pre-line">
                      {msg.text.split('\n').map((line, lIdx) => {
                        if (line.startsWith('### ')) {
                          return (
                            <h4
                              key={lIdx}
                              className="text-xs font-black text-[#15120F] dark:text-[#F6EFE8] mt-2 mb-1"
                            >
                              {line.replace(/^###\s*/, '')}
                            </h4>
                          );
                        }

                        // Simple parser for bold tags like **text**
                        const parts = line.split(/(\*\*.*?\*\*)/g);
                        return (
                          <p key={lIdx} className={line.startsWith('•') ? 'pl-2 my-0.5' : 'my-1'}>
                            {parts.map((part, pIdx) => {
                              if (part.startsWith('**') && part.endsWith('**')) {
                                return (
                                  <strong
                                    key={pIdx}
                                    className="font-bold text-[#15120F] dark:text-[#F6EFE8]"
                                  >
                                    {part.slice(2, -2)}
                                  </strong>
                                );
                              }
                              return part;
                            })}
                          </p>
                        );
                      })}
                    </div>

                    {/* Stats pills if provided by Pan */}
                    {!isUser && msg.response?.stats && msg.response.stats.length > 0 && (
                      <div className="grid grid-cols-2 sm:grid-cols-3 gap-1.5 pt-1">
                        {msg.response.stats.map((st, sIdx) => (
                          <div
                            key={sIdx}
                            className="p-2 rounded-xl bg-[#FBF2EA] dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] flex flex-col"
                          >
                            <span className="text-[9px] uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92] font-semibold truncate">
                              {st.label}
                            </span>
                            <span
                              className="text-xs font-black truncate tabular-nums"
                              style={{ color: st.color || undefined }}
                            >
                              {st.value}
                            </span>
                          </div>
                        ))}
                      </div>
                    )}

                    {/* Deep link Action Buttons */}
                    {!isUser && msg.response?.actions && msg.response.actions.length > 0 && (
                      <div className="flex flex-wrap gap-1.5 pt-2 border-t border-[#F3DFCD]/80 dark:border-[#383029]/80">
                        {msg.response.actions.map((act, aIdx) => (
                          <button
                            key={aIdx}
                            type="button"
                            onClick={() => handleActionClick(act.actionId, act.payload)}
                            className="px-2.5 py-1.5 rounded-xl text-[11px] font-bold bg-[#FFEEDF] dark:bg-[#2A221C] hover:bg-[#B03C09] hover:text-white dark:hover:bg-[#FF9A52] dark:hover:text-[#14100D] text-[#B03C09] dark:text-[#FF9A52] transition-colors flex items-center gap-1 cursor-pointer border border-[#F0D5C0] dark:border-[#383029]"
                          >
                            <span>{act.label}</span>
                            <ArrowRight size={11} />
                          </button>
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Suggested Follow-Ups */}
                  {!isUser && msg.response?.suggestedFollowUps && (
                    <div className="flex flex-wrap gap-1.5 mt-2 pl-1 max-w-[90%]">
                      {msg.response.suggestedFollowUps.map((su, sIdx) => (
                        <button
                          key={sIdx}
                          type="button"
                          onClick={() => handleSendMessage(su)}
                          className="text-[10px] font-semibold px-2 py-0.5 rounded-lg bg-white/70 dark:bg-[#27201A]/70 text-[#6B6156] dark:text-[#AC9E92] hover:text-[#B03C09] dark:hover:text-[#FF9A52] border border-[#F3DFCD] dark:border-[#383029] transition-colors cursor-pointer"
                        >
                          ↳ {su}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              );
            })}

            {isTyping && (
              <div className="flex items-center gap-2 p-3 bg-white dark:bg-[#1E1915] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl rounded-tl-xs w-28 text-[#6B6156] dark:text-[#AC9E92] shadow-2xs">
                <span className="w-2 h-2 rounded-full bg-[#B03C09] dark:bg-[#FF9A52] animate-bounce" />
                <span className="w-2 h-2 rounded-full bg-[#B03C09] dark:bg-[#FF9A52] animate-bounce [animation-delay:0.2s]" />
                <span className="w-2 h-2 rounded-full bg-[#B03C09] dark:bg-[#FF9A52] animate-bounce [animation-delay:0.4s]" />
              </div>
            )}

            <div ref={messagesEndRef} />
          </div>

          {/* Chat Input Bar */}
          <form
            onSubmit={(e) => {
              e.preventDefault();
              handleSendMessage();
            }}
            className="p-3 bg-white dark:bg-[#1E1915] border-t border-[#F3DFCD] dark:border-[#383029] flex items-center gap-2 shrink-0"
          >
            <input
              type="text"
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              placeholder="Ask Pan about your bills, cards, or safe to spend..."
              className="flex-1 min-w-0 px-3.5 py-2.5 rounded-2xl bg-[#FFEEDF]/50 dark:bg-[#14100D]/70 border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09] dark:focus:border-[#FF9A52] placeholder-[#6B6156]/70 dark:placeholder-[#AC9E92]/70"
            />
            <button
              type="submit"
              disabled={!inputValue.trim()}
              className="p-2.5 rounded-2xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] disabled:opacity-40 hover:opacity-90 active:scale-95 transition-all cursor-pointer shrink-0 shadow-xs flex items-center justify-center min-w-[42px] min-h-[42px]"
              aria-label="Send message"
            >
              <Send size={16} />
            </button>
          </form>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};
