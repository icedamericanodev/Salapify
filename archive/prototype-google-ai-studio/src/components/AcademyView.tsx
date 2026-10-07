import React, { useState, useEffect, useMemo } from 'react';
import { 
  ChevronLeft, CheckCircle2, PlayCircle, 
  ArrowRight, BrainCircuit, AlertCircle, Search, 
  Sparkles, RotateCcw, Award, Check, Building2, BookOpen, Compass
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { academyCourses, CourseModule } from '../data/academyData';
import { PHBusinessStartupGuide } from './PHBusinessStartupGuide';

interface AcademyViewProps {
  initialMode?: 'courses' | 'startup_guide';
  initialStartupTab?: 'entities' | 'roadmap' | 'checklist' | 'experts' | 'saas';
  initialSaasSubTab?: 'overview' | 'stores' | 'billing' | 'taxation' | 'survival' | 'calculator';
}

export const AcademyView: React.FC<AcademyViewProps> = ({
  initialMode = 'courses',
  initialStartupTab = 'roadmap',
  initialSaasSubTab = 'overview',
}) => {
  const [selectedCourse, setSelectedCourse] = useState<CourseModule | null>(null);
  const [completedCourses, setCompletedCourses] = useState<string[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('All');
  const [academyMode, setAcademyMode] = useState<'courses' | 'startup_guide'>(initialMode);

  useEffect(() => {
    if (initialMode) {
      setAcademyMode(initialMode);
    }
  }, [initialMode]);

  // Load progress on mount
  useEffect(() => {
    const saved = localStorage.getItem('salapify_academy_progress');
    if (saved) {
      try {
        setCompletedCourses(JSON.parse(saved));
      } catch (e) {
        console.error('Failed to load academy progress', e);
      }
    }
  }, []);

  const markAsComplete = (id: string) => {
    if (!completedCourses.includes(id)) {
      const newCompleted = [...completedCourses, id];
      setCompletedCourses(newCompleted);
      localStorage.setItem('salapify_academy_progress', JSON.stringify(newCompleted));
    }
    setSelectedCourse(null);
  };

  const toggleCourseStatus = (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    let newCompleted: string[];
    if (completedCourses.includes(id)) {
      newCompleted = completedCourses.filter(cId => cId !== id);
    } else {
      newCompleted = [...completedCourses, id];
    }
    setCompletedCourses(newCompleted);
    localStorage.setItem('salapify_academy_progress', JSON.stringify(newCompleted));
  };

  // Categories list
  const categories = useMemo(() => {
    const set = new Set<string>();
    academyCourses.forEach(c => set.add(c.category));
    return ['All', ...Array.from(set)];
  }, []);

  // Filtered courses
  const filteredCourses = useMemo(() => {
    return academyCourses.filter(course => {
      const matchesCategory = selectedCategory === 'All' || course.category === selectedCategory;
      const query = searchQuery.trim().toLowerCase();
      const matchesQuery = !query || 
        course.title.toLowerCase().includes(query) ||
        course.description.toLowerCase().includes(query) ||
        course.category.toLowerCase().includes(query) ||
        course.keyTakeaways.some(t => t.toLowerCase().includes(query));
      return matchesCategory && matchesQuery;
    });
  }, [selectedCategory, searchQuery]);

  const progressPercent = Math.round((completedCourses.length / academyCourses.length) * 100);

  // If in Startup Guide mode, render the guide
  if (academyMode === 'startup_guide') {
    return (
      <PHBusinessStartupGuide
        onBackToLessons={() => setAcademyMode('courses')}
        initialTab={initialStartupTab}
        initialSaasSubTab={initialSaasSubTab}
      />
    );
  }

  // Main Course Catalog View
  if (!selectedCourse) {
    return (
      <div className="space-y-4 pb-8">
        {/* Track Switcher */}
        <div className="flex items-center gap-1.5 p-1 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl">
          <button
            type="button"
            onClick={() => setAcademyMode('courses')}
            className={`flex-1 py-2 rounded-lg text-xs font-bold transition-all flex items-center justify-center gap-2 min-h-[44px] ${
              academyMode === 'courses'
                ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] shadow-xs'
                : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
            }`}
          >
            <BookOpen size={16} />
            <span>Curriculum Courses ({academyCourses.length})</span>
          </button>
          <button
            type="button"
            onClick={() => setAcademyMode('startup_guide')}
            className="flex-1 py-2 rounded-lg text-xs font-bold transition-all flex items-center justify-center gap-2 min-h-[44px] text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8]"
          >
            <Building2 size={16} />
            <span>PH Startup Guide</span>
            <span className="text-[9px] px-1.5 py-0.2 rounded-full font-bold bg-[#FFEEDF] text-[#B03C09] dark:bg-[#383029] dark:text-[#FF9A52]">
              PH
            </span>
          </button>
        </div>

        {/* Progress & Header Banner */}
        <div className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-4 sm:p-5 shadow-xs">
          <div className="flex items-center justify-between gap-3 mb-3">
            <div>
              <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                Financial Literacy Track
              </span>
              <h2 className="text-base sm:text-lg font-black text-[#15120F] dark:text-[#F6EFE8]">
                Salapify Academy
              </h2>
            </div>
            <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] text-xs font-bold shrink-0">
              <Award size={16} />
              <span>{completedCourses.length} / {academyCourses.length} Done</span>
            </div>
          </div>

          {/* Progress Bar */}
          <div className="space-y-1.5">
            <div className="flex justify-between text-xs font-semibold text-[#6B6156] dark:text-[#AC9E92]">
              <span>Overall Progress</span>
              <span>{progressPercent}% Complete</span>
            </div>
            <div className="w-full h-2.5 bg-[#FFEEDF] dark:bg-[#383029] rounded-full overflow-hidden">
              <motion.div 
                className="h-full bg-[#B03C09] dark:bg-[#FF9A52] rounded-full"
                initial={{ width: 0 }}
                animate={{ width: `${progressPercent}%` }}
                transition={{ duration: 0.6, ease: 'easeOut' }}
              />
            </div>
          </div>
        </div>

        {/* Regulatory Disclaimer */}
        <div className="bg-[#FFEEDF]/60 dark:bg-[#383029]/50 border border-[#F3DFCD] dark:border-[#5A5148] rounded-xl p-3.5 flex items-start gap-3">
          <AlertCircle size={18} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0 mt-0.5" />
          <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
            <strong className="text-[#15120F] dark:text-[#F6EFE8]">Educational Empowerment:</strong> Salapify Academy lessons are crafted by financial educators and behavioral scientists for general knowledge. They do not constitute regulated tax, legal, or investment advice.
          </p>
        </div>

        {/* Featured Card: Philippine Business Startup Guide */}
        <div className="p-4 rounded-2xl bg-gradient-to-br from-[#FFF8F3] to-[#FFEEDF] dark:from-[#2A211B] dark:to-[#1E1915] border border-[#F3DFCD] dark:border-[#5A5148] flex flex-col sm:flex-row sm:items-center justify-between gap-3 shadow-xs">
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-xl bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center shrink-0 shadow-xs mt-0.5">
              <Building2 size={20} />
            </div>
            <div>
              <div className="flex items-center gap-1.5 flex-wrap">
                <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                  Interactive Roadmap
                </span>
                <span className="text-[9px] font-bold px-1.5 py-0.2 rounded bg-white/80 dark:bg-[#1E1915] text-[#15120F] dark:text-[#F6EFE8]">
                  PHILIPPINES
                </span>
              </div>
              <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Building a Business or Startup in the Philippines?
              </h3>
              <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] mt-0.5">
                Explore the complete guide: Sole Prop vs. OPC vs. Corp, DTI, SEC, IPOPHL Trademarks, Mayor\'s Permits, BIR Form 2303, and digital compliance (NPC, NTC, E-Commerce).
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={() => setAcademyMode('startup_guide')}
            className="px-3.5 py-2.5 rounded-xl bg-[#B03C09] hover:bg-[#963307] dark:bg-[#FF9A52] dark:hover:bg-[#ff8a38] text-white dark:text-[#14100D] text-xs font-bold shrink-0 shadow-xs transition-all flex items-center justify-center gap-1.5 min-h-[44px] cursor-pointer"
          >
            <span>Open Startup Guide</span>
            <ArrowRight size={14} />
          </button>
        </div>

        {/* Search & Category Filter */}
        <div className="space-y-3">
          {/* Search Box */}
          <div className="relative">
            <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[#AC9E92] pointer-events-none" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search topics (e.g., MP2, credit cards, taxes, buffer)..."
              className="w-full bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl pl-10 pr-4 py-2.5 text-sm text-[#15120F] dark:text-[#F6EFE8] placeholder-[#AC9E92] focus:outline-none focus:border-[#B03C09] dark:focus:border-[#FF9A52] transition-colors"
            />
            {searchQuery && (
              <button 
                type="button"
                onClick={() => setSearchQuery('')}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] p-1"
              >
                Clear
              </button>
            )}
          </div>

          {/* Category Chips */}
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar">
            {categories.map((cat) => {
              const isSelected = selectedCategory === cat;
              return (
                <button
                  key={cat}
                  type="button"
                  onClick={() => setSelectedCategory(cat)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold whitespace-nowrap transition-all shrink-0 ${
                    isSelected
                      ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] shadow-xs'
                      : 'bg-white dark:bg-[#27201A] text-[#6B6156] dark:text-[#AC9E92] border border-[#F3DFCD] dark:border-[#383029] hover:border-[#B03C09]/40'
                  }`}
                >
                  {cat}
                </button>
              );
            })}
          </div>
        </div>

        {/* Empty State */}
        {filteredCourses.length === 0 && (
          <div className="text-center py-12 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl p-6">
            <Search size={32} className="mx-auto text-[#AC9E92] mb-3 opacity-60" />
            <h3 className="text-sm font-bold text-[#15120F] dark:text-[#F6EFE8] mb-1">
              No topics matched your search
            </h3>
            <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] mb-4">
              Try searching for terms like "sweldo", "savings", "debt", or "investing".
            </p>
            <button
              type="button"
              onClick={() => { setSearchQuery(''); setSelectedCategory('All'); }}
              className="px-4 py-2 bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] rounded-xl text-xs font-bold"
            >
              Reset Filters
            </button>
          </div>
        )}

        {/* Courses Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {filteredCourses.map((course) => {
            const Icon = course.iconName;
            const isCompleted = completedCourses.includes(course.id);

            return (
              <div
                key={course.id}
                onClick={() => setSelectedCourse(course)}
                role="button"
                tabIndex={0}
                onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') setSelectedCourse(course); }}
                className="flex flex-col text-left p-4 rounded-2xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] hover:border-[#B03C09] dark:hover:border-[#FF9A52] transition-all shadow-xs group relative overflow-hidden cursor-pointer"
              >
                {/* Done badge toggle */}
                <div className="flex items-center justify-between gap-2 mb-2">
                  <div className="flex items-center gap-2.5">
                    <div className={`p-2 rounded-xl flex items-center justify-center shrink-0 transition-colors ${
                      isCompleted 
                        ? 'bg-[#16643F]/10 text-[#16643F] dark:bg-[#5FCB8E]/15 dark:text-[#5FCB8E]' 
                        : 'bg-[#FFEEDF] text-[#B03C09] dark:bg-[#383029] dark:text-[#FF9A52] group-hover:bg-[#B03C09] group-hover:text-white dark:group-hover:bg-[#FF9A52] dark:group-hover:text-[#14100D]'
                    }`}>
                      <Icon size={18} strokeWidth={2} />
                    </div>
                    <div>
                      <span className="text-[10px] font-bold uppercase tracking-wider text-[#6B6156] dark:text-[#AC9E92]">
                        {course.category}
                      </span>
                      <h3 className="text-sm font-extrabold text-[#15120F] dark:text-[#F6EFE8] leading-tight">
                        {course.title}
                      </h3>
                    </div>
                  </div>

                  <button
                    type="button"
                    title={isCompleted ? 'Mark as incomplete' : 'Mark as completed'}
                    onClick={(e) => toggleCourseStatus(course.id, e)}
                    className={`p-1.5 rounded-lg shrink-0 transition-colors ${
                      isCompleted
                        ? 'bg-[#16643F] text-white dark:bg-[#5FCB8E] dark:text-[#14100D]'
                        : 'text-[#AC9E92] hover:text-[#B03C09] dark:hover:text-[#FF9A52] bg-[#FAFAFA] dark:bg-[#1A1512]'
                    }`}
                  >
                    <Check size={14} strokeWidth={isCompleted ? 3 : 2} />
                  </button>
                </div>
                
                <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] line-clamp-2 mt-1 leading-relaxed">
                  {course.description}
                </p>

                <div className="mt-4 pt-3 border-t border-[#F3DFCD]/40 dark:border-[#383029]/60 flex items-center justify-between text-xs font-semibold">
                  <span className="text-[#6B6156] dark:text-[#AC9E92] flex items-center gap-1">
                    <PlayCircle size={14} /> {course.durationMinutes} min
                  </span>
                  <span className="text-[#B03C09] dark:text-[#FF9A52] flex items-center gap-1 group-hover:translate-x-0.5 transition-transform font-bold">
                    {isCompleted ? 'Review Lesson' : 'Start Lesson'} <ArrowRight size={14} />
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    );
  }

  // Active Lesson View
  return (
    <LessonRunner 
      course={selectedCourse} 
      onClose={() => setSelectedCourse(null)} 
      onComplete={() => markAsComplete(selectedCourse.id)} 
    />
  );
};

// --- Subcomponent: The Interactive Lesson Runner --- //

interface LessonRunnerProps {
  course: CourseModule;
  onClose: () => void;
  onComplete: () => void;
}

const LessonRunner: React.FC<LessonRunnerProps> = ({ course, onClose, onComplete }) => {
  const [activeSectionIdx, setActiveSectionIdx] = useState(0);
  const [selectedAnswer, setSelectedAnswer] = useState<number | null>(null);
  const [showExplanation, setShowExplanation] = useState(false);
  const [reflectionText, setReflectionText] = useState('');
  const [savedNoteStatus, setSavedNoteStatus] = useState<string>('');

  // Track which parts the user has viewed/reviewed
  const [reviewedParts, setReviewedParts] = useState<number[]>(() => {
    try {
      const saved = localStorage.getItem(`salapify_viewed_parts_${course.id}`);
      if (saved) {
        const parsed = JSON.parse(saved);
        if (Array.isArray(parsed)) return parsed.includes(0) ? parsed : [0, ...parsed];
      }
    } catch {
      // ignore
    }
    return [0];
  });

  const Icon = course.iconName;

  // Load saved reflection if any
  useEffect(() => {
    const saved = localStorage.getItem(`salapify_reflection_${course.id}`);
    if (saved) {
      setReflectionText(saved);
    }
    // Scroll smoothly to top on mount
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }, [course.id]);

  // When activeSectionIdx changes, mark it as reviewed and persist
  useEffect(() => {
    setReviewedParts((prev) => {
      if (!prev.includes(activeSectionIdx)) {
        const updated = [...prev, activeSectionIdx];
        try {
          localStorage.setItem(`salapify_viewed_parts_${course.id}`, JSON.stringify(updated));
        } catch {
          // ignore
        }
        return updated;
      }
      return prev;
    });
  }, [activeSectionIdx, course.id]);

  const handleSaveReflection = (val: string) => {
    setReflectionText(val);
    localStorage.setItem(`salapify_reflection_${course.id}`, val);
    setSavedNoteStatus('Saved locally');
    setTimeout(() => setSavedNoteStatus(''), 2500);
  };

  const handleResetQuiz = () => {
    setSelectedAnswer(null);
    setShowExplanation(false);
  };

  const allPartsReviewed = course.sections.every((_, idx) => reviewedParts.includes(idx));

  return (
    <motion.div 
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -10 }}
      className="bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-2xl shadow-sm overflow-hidden mb-8"
    >
      {/* Lesson Header with prominent Back button */}
      <div className="p-3 sm:p-4 border-b border-[#F3DFCD] dark:border-[#383029] flex items-center justify-between gap-3 sticky top-0 bg-white/95 dark:bg-[#27201A]/95 backdrop-blur-md z-10">
        <div className="flex items-center gap-2 sm:gap-3 min-w-0">
          <button 
            type="button"
            onClick={onClose}
            className="px-3 py-2 rounded-xl bg-[#FAFAFA] dark:bg-[#1A1512] hover:bg-[#FFEEDF] dark:hover:bg-[#383029] text-[#6B6156] dark:text-[#AC9E92] hover:text-[#B03C09] dark:hover:text-[#FF9A52] border border-[#F3DFCD]/60 dark:border-[#383029] transition-colors min-h-[44px] flex items-center gap-1.5 text-xs font-bold shrink-0"
            aria-label="Back to lessons catalog"
          >
            <ChevronLeft size={18} />
            <span>Back to Lessons</span>
          </button>
          <div className="min-w-0">
            <span className="text-[10px] font-bold uppercase tracking-widest text-[#B03C09] dark:text-[#FF9A52] block truncate">
              {course.category}
            </span>
            <h2 className="text-sm sm:text-base font-black text-[#15120F] dark:text-[#F6EFE8] truncate">
              {course.title}
            </h2>
          </div>
        </div>
        <div className="p-2 rounded-xl bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] shrink-0">
          <Icon size={20} />
        </div>
      </div>

      <div className="p-4 sm:p-6 space-y-6">
        
        {/* Learning Objectives */}
        <section className="bg-[#FFEEDF]/40 dark:bg-[#383029]/30 rounded-xl p-4 border border-[#F3DFCD] dark:border-[#383029]">
          <h3 className="text-xs font-extrabold uppercase tracking-widest text-[#B03C09] dark:text-[#FF9A52] mb-2.5">
            Learning Objectives:
          </h3>
          <ul className="space-y-2">
            {course.objectives.map((obj, idx) => (
              <li key={idx} className="flex items-start gap-2.5 text-xs sm:text-sm text-[#15120F] dark:text-[#F6EFE8] font-medium leading-snug">
                <CheckCircle2 size={16} className="text-[#16643F] dark:text-[#5FCB8E] shrink-0 mt-0.5" />
                <span>{obj}</span>
              </li>
            ))}
          </ul>
        </section>

        {/* Section Navigation Tabs & Review Status */}
        {course.sections.length > 1 && (
          <div className="space-y-2 border-b border-[#F3DFCD] dark:border-[#383029] pb-3">
            <div className="flex items-center justify-between text-xs">
              <span className="font-bold text-[#6B6156] dark:text-[#AC9E92]">
                Lesson Parts ({reviewedParts.length}/{course.sections.length} reviewed)
              </span>
              {!allPartsReviewed && (
                <span className="text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52]">
                  Review all {course.sections.length} parts to complete
                </span>
              )}
            </div>
            <div className="flex items-center gap-1.5 overflow-x-auto no-scrollbar">
              {course.sections.map((sec, idx) => {
                const isReviewed = reviewedParts.includes(idx);
                const isActive = activeSectionIdx === idx;
                return (
                  <button
                    key={sec.id}
                    type="button"
                    onClick={() => setActiveSectionIdx(idx)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-colors flex items-center gap-1.5 shrink-0 ${
                      isActive
                        ? 'bg-[#B03C09] text-white dark:bg-[#FF9A52] dark:text-[#14100D] shadow-xs'
                        : isReviewed
                        ? 'bg-[#FFEEDF] text-[#B03C09] dark:bg-[#383029] dark:text-[#FF9A52]'
                        : 'bg-[#FAFAFA] dark:bg-[#1A1512] text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] border border-[#F3DFCD]/50 dark:border-[#383029]/50'
                    }`}
                  >
                    <span>Part {idx + 1}</span>
                    {isReviewed && <Check size={12} strokeWidth={3} />}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Content Sections */}
        <div className="space-y-4">
          <motion.section 
            key={course.sections[activeSectionIdx].id}
            initial={{ opacity: 0, x: 5 }}
            animate={{ opacity: 1, x: 0 }}
            className="space-y-2"
          >
            <div className="flex items-center gap-2">
              <span className="text-xs font-extrabold px-2 py-0.5 rounded bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52]">
                {activeSectionIdx + 1} of {course.sections.length}
              </span>
              <h3 className="text-base sm:text-lg font-bold text-[#15120F] dark:text-[#F6EFE8]">
                {course.sections[activeSectionIdx].title}
              </h3>
            </div>
            <p className="text-sm text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed whitespace-pre-line">
              {course.sections[activeSectionIdx].content}
            </p>
          </motion.section>

          {/* Step buttons if multiple sections */}
          {course.sections.length > 1 && (
            <div className="flex items-center justify-between pt-2">
              <button
                type="button"
                disabled={activeSectionIdx === 0}
                onClick={() => setActiveSectionIdx(prev => Math.max(0, prev - 1))}
                className="px-3 py-2 text-xs font-bold text-[#6B6156] dark:text-[#AC9E92] disabled:opacity-30 flex items-center gap-1 hover:text-[#15120F] dark:hover:text-[#F6EFE8] min-h-[44px]"
              >
                <ChevronLeft size={14} /> Previous Part
              </button>
              <button
                type="button"
                disabled={activeSectionIdx === course.sections.length - 1}
                onClick={() => setActiveSectionIdx(prev => Math.min(course.sections.length - 1, prev + 1))}
                className="px-3 py-2 text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] disabled:opacity-30 flex items-center gap-1 hover:opacity-80 min-h-[44px]"
              >
                Next Part <ArrowRight size={14} />
              </button>
            </div>
          )}
        </div>

        {/* Interactive Reflection Prompt */}
        {course.reflectionPrompt && (
          <section className="bg-[#FFEEDF]/30 dark:bg-[#383029]/30 rounded-xl p-4 border border-[#B03C09]/20 dark:border-[#FF9A52]/20 space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <BrainCircuit size={18} className="text-[#B03C09] dark:text-[#FF9A52]" />
                <h3 className="text-xs sm:text-sm font-bold text-[#15120F] dark:text-[#F6EFE8]">
                  Behavioral Reflection
                </h3>
              </div>
              {savedNoteStatus && (
                <span className="text-[10px] text-[#16643F] dark:text-[#5FCB8E] font-bold">
                  {savedNoteStatus}
                </span>
              )}
            </div>
            <p className="text-xs sm:text-sm text-[#5A5148] dark:text-[#C6B8AC] italic leading-relaxed">
              "{course.reflectionPrompt}"
            </p>
            <textarea 
              value={reflectionText}
              onChange={(e) => handleSaveReflection(e.target.value)}
              placeholder="Write your personal thoughts here (stored 100% privately on your device)..."
              className="w-full bg-white dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#5A5148] rounded-xl p-3 text-xs sm:text-sm text-[#15120F] dark:text-[#F6EFE8] placeholder-[#AC9E92] focus:outline-none focus:ring-2 focus:ring-[#B03C09]/40 min-h-[90px] resize-none leading-relaxed"
            />
          </section>
        )}

        {/* Interactive Knowledge Check */}
        {course.knowledgeCheck && (
          <section className="bg-[#FAFAFA] dark:bg-[#1A1512] rounded-xl p-4 sm:p-5 border border-[#F3DFCD] dark:border-[#383029] space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-bold uppercase tracking-wider text-[#B03C09] dark:text-[#FF9A52]">
                Knowledge Check
              </span>
              {showExplanation && (
                <button
                  type="button"
                  onClick={handleResetQuiz}
                  className="text-[11px] font-bold text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] flex items-center gap-1"
                >
                  <RotateCcw size={12} /> Try Again
                </button>
              )}
            </div>

            <h3 className="text-xs sm:text-sm font-extrabold text-[#15120F] dark:text-[#F6EFE8] leading-snug">
              {course.knowledgeCheck.question}
            </h3>

            <div className="space-y-2 pt-1">
              {course.knowledgeCheck.options.map((option, idx) => {
                const isSelected = selectedAnswer === idx;
                const isCorrect = idx === course.knowledgeCheck?.correctAnswerIndex;

                let btnClass = "w-full text-left p-3 rounded-xl border text-xs sm:text-sm transition-all min-h-[44px] flex items-start gap-2.5 ";
                if (showExplanation) {
                  if (isCorrect) {
                    btnClass += "bg-[#16643F]/10 border-[#16643F] text-[#16643F] dark:bg-[#5FCB8E]/15 dark:border-[#5FCB8E] dark:text-[#5FCB8E] font-bold";
                  } else if (isSelected && !isCorrect) {
                    btnClass += "bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800 text-red-700 dark:text-red-400 opacity-80";
                  } else {
                    btnClass += "bg-white dark:bg-[#27201A] border-[#F3DFCD] dark:border-[#383029] text-[#6B6156] dark:text-[#AC9E92] opacity-40";
                  }
                } else {
                  btnClass += isSelected 
                    ? "bg-[#FFEEDF] dark:bg-[#383029] border-[#B03C09] dark:border-[#FF9A52] text-[#B03C09] dark:text-[#FF9A52] font-bold"
                    : "bg-white dark:bg-[#27201A] border-[#F3DFCD] dark:border-[#383029] text-[#5A5148] dark:text-[#C6B8AC] hover:border-[#B03C09]/50";
                }

                return (
                  <button
                    key={idx}
                    type="button"
                    disabled={showExplanation}
                    onClick={() => setSelectedAnswer(idx)}
                    className={btnClass}
                  >
                    <span className="font-mono text-xs opacity-70 mt-0.5">
                      {String.fromCharCode(65 + idx)}.
                    </span>
                    <span className="flex-1">{option}</span>
                  </button>
                );
              })}
            </div>
            
            {!showExplanation && selectedAnswer !== null && (
              <button 
                type="button"
                onClick={() => setShowExplanation(true)}
                className="mt-3 w-full py-3 bg-[#15120F] dark:bg-[#F6EFE8] text-white dark:text-[#14100D] rounded-xl font-bold text-xs sm:text-sm shadow-xs min-h-[44px]"
              >
                Submit Answer
              </button>
            )}

            {showExplanation && (
              <motion.div 
                initial={{ opacity: 0, y: 4 }}
                animate={{ opacity: 1, y: 0 }}
                className={`mt-3 p-3.5 rounded-xl border-l-4 ${
                  selectedAnswer === course.knowledgeCheck.correctAnswerIndex
                    ? 'bg-[#16643F]/10 border-[#16643F] text-[#16643F] dark:bg-[#5FCB8E]/10 dark:border-[#5FCB8E] dark:text-[#5FCB8E]'
                    : 'bg-[#FFEEDF] border-[#B03C09] text-[#15120F] dark:bg-[#383029] dark:border-[#FF9A52] dark:text-[#F6EFE8]'
                }`}
              >
                <div className="font-extrabold text-xs mb-1">
                  {selectedAnswer === course.knowledgeCheck.correctAnswerIndex ? 'Correct!' : 'Keep Learning:'}
                </div>
                <p className="text-xs sm:text-sm leading-relaxed">
                  {course.knowledgeCheck.explanation}
                </p>
              </motion.div>
            )}
          </section>
        )}

        {/* Key Takeaways */}
        <section className="pt-4 border-t border-[#F3DFCD] dark:border-[#383029]">
          <h3 className="text-xs font-extrabold uppercase tracking-widest text-[#B03C09] dark:text-[#FF9A52] mb-3">
            Key Takeaways
          </h3>
          <ul className="space-y-2">
            {course.keyTakeaways.map((takeaway, idx) => (
              <li key={idx} className="flex items-start gap-2.5 text-xs sm:text-sm text-[#15120F] dark:text-[#F6EFE8] font-bold leading-snug">
                <span className="text-[#B03C09] dark:text-[#FF9A52] font-black shrink-0 text-base leading-none">•</span>
                <span>{takeaway}</span>
              </li>
            ))}
          </ul>
        </section>

      </div>

      {/* Footer Action: Back button for partial lesson exit + Complete button gated on reviewing all parts */}
      <div className="p-4 border-t border-[#F3DFCD] dark:border-[#383029] bg-[#FAFAFA] dark:bg-[#1A1512] space-y-2.5">
        <div className="flex flex-col sm:flex-row items-center gap-2.5">
          <button
            type="button"
            onClick={onClose}
            className="w-full sm:w-auto px-4 py-3 border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] rounded-xl font-bold text-xs sm:text-sm transition-colors min-h-[44px] flex items-center justify-center gap-2 shrink-0"
          >
            <ChevronLeft size={16} />
            Back to Lessons
          </button>
          
          <button
            type="button"
            disabled={!allPartsReviewed}
            onClick={onComplete}
            className={`w-full sm:flex-1 py-3 rounded-xl font-bold text-xs sm:text-sm shadow-xs transition-all flex items-center justify-center gap-2 min-h-[44px] ${
              allPartsReviewed
                ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#14100D] hover:opacity-90 active:scale-98 cursor-pointer'
                : 'bg-[#E5D8CD] dark:bg-[#383029] text-[#8C7D70] dark:text-[#7A6E63] cursor-not-allowed opacity-80'
            }`}
          >
            <CheckCircle2 size={18} />
            {allPartsReviewed 
              ? 'Complete Lesson' 
              : `Review All Parts to Complete (${reviewedParts.length}/${course.sections.length} parts read)`}
          </button>
        </div>

        {!allPartsReviewed && (
          <p className="text-[11px] text-center text-[#7A6E63] dark:text-[#A89A8D]">
            Not ready to finish all parts right now? Tap <strong>Back to Lessons</strong> anytime. Your progress and notes are saved on this device.
          </p>
        )}
      </div>
    </motion.div>
  );
};
