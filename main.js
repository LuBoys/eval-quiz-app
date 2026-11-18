import { liquidMetalFragmentShader, ShaderMount } from "@paper-design/shaders";
import "./style.css";

const API_URL = "/api";
const QUESTION_TIME = 30;
const ANSWER_FEEDBACK_TIME = 4000;
const TIMEOUT_FEEDBACK_TIME = 2000;

const subjects = new Map([
  ["docker", "Docker"],
  ["ansible", "Ansible"],
  ["devops", "DevOps"],
  ["cicd", "CI/CD"],
  ["scm", "Git et SCM"],
  ["usine-logicielle", "Usine logicielle"],
]);
const questionModules = import.meta.glob("./questions_*.js");

const app = document.querySelector("#app");
const registration = cloneTemplate("registration-template");
const registrationForm = registration.querySelector("form");
const subjectOptions = registrationForm.querySelector(".subject-options");

for (const [index, [value, label]] of [...subjects].entries()) {
  const option = document.createElement("label");
  const input = document.createElement("input");
  const pill = document.createElement("span");

  option.className = "subject-option";
  option.style.setProperty("--order", index);
  input.className = "visually-hidden";
  input.type = "radio";
  input.name = "subject";
  input.value = value;
  input.required = true;
  pill.className = "subject-pill";
  pill.textContent = label;
  option.append(input, pill);
  subjectOptions.append(option);
}
registrationForm.addEventListener("submit", handleRegistration);
prepareWelcome();

function cloneTemplate(id) {
  return document.getElementById(id).content.firstElementChild.cloneNode(true);
}

function prepareWelcome() {
  const welcome = app.querySelector(".welcome");
  const heading = welcome.querySelector("h1");
  const button = welcome.querySelector("button");
  const metal = button.querySelector(".welcome-metal");
  const words = heading.textContent.trim().split(/\s+/);
  const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
  let shader;

  welcome.style.setProperty("--word-count", words.length);
  heading.replaceChildren(...words.flatMap((word, index) => {
    const part = document.createElement("span");
    part.className = "welcome-word";
    part.style.setProperty("--word-order", index);
    part.textContent = word;
    return [part, " "];
  }));

  function updateMetalSpeed() {
    const speed = button.disabled ? 2.4 : button.matches(":hover") ? 1 : 0.6;
    shader?.setSpeed(reducedMotion.matches ? 0 : speed);
  }

  button.addEventListener("pointerenter", updateMetalSpeed);
  button.addEventListener("pointerleave", updateMetalSpeed);
  reducedMotion.addEventListener("change", updateMetalSpeed);
  button.addEventListener("click", async (event) => {
    button.disabled = true;
    if (!reducedMotion.matches) addWelcomeRipple(button, event);
    updateMetalSpeed();
    welcome.classList.add("is-leaving");

    const exitAnimations = welcome.getAnimations({ subtree: true })
      .filter((animation) => animation.animationName === "welcome-out");
    await Promise.allSettled(exitAnimations.map((animation) => animation.finished));

    reducedMotion.removeEventListener("change", updateMetalSpeed);
    shader?.dispose();
    showScreen(registration);
  }, { once: true });

  try {
    shader = new ShaderMount(metal, liquidMetalFragmentShader, {
      u_repetition: 4,
      u_softness: 0.5,
      u_shiftRed: 0.3,
      u_shiftBlue: 0.3,
      u_distortion: 0,
      u_contour: 0,
      u_angle: 45,
      u_scale: 8,
      u_shape: 1,
      u_fit: 1,
      u_originX: 0.5,
      u_originY: 0.5,
      u_offsetX: 0.1,
      u_offsetY: -0.1,
    });
    updateMetalSpeed();
  } catch {
    // The CSS gradient is the fallback when WebGL is unavailable.
    metal.replaceChildren();
  }
}

function addWelcomeRipple(button, event) {
  const { left, top, width, height } = button.getBoundingClientRect();
  const ripple = document.createElement("span");
  ripple.className = "welcome-ripple";
  ripple.setAttribute("aria-hidden", "true");
  ripple.style.left = `${event.detail ? event.clientX - left : width / 2}px`;
  ripple.style.top = `${event.detail ? event.clientY - top : height / 2}px`;
  button.append(ripple);
}

function showScreen(screen) {
  screen.classList.remove("is-leaving");
  app.replaceChildren(screen);
  window.scrollTo(0, 0);
  screen.querySelector("h1").focus({ preventScroll: true });
}

async function leaveScreen(screen) {
  screen.classList.add("is-leaving");
  const animation = screen.getAnimations().find((item) => item.animationName === "screen-out");
  await animation?.finished.catch(() => {});
}

function shuffleArray(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
  return array;
}

async function handleRegistration(event) {
  event.preventDefault();
  const submitButton = registrationForm.querySelector("button");
  if (submitButton.disabled) return;

  const { firstname, email, subject, website } = Object.fromEntries(
    new FormData(registrationForm),
  );
  const subjectLabel = subjects.get(subject);
  const loadQuestions = questionModules[`./questions_${subject}.js`];
  const fields = registrationForm.querySelector("fieldset");
  const buttonLabel = submitButton.querySelector(".button-label");
  const errorMessage = registrationForm.querySelector(".form-error");

  if (!subjectLabel || !loadQuestions) {
    errorMessage.textContent = "Choisis un sujet.";
    return;
  }

  errorMessage.textContent = "";
  fields.disabled = true;
  submitButton.disabled = true;
  buttonLabel.textContent = "Chargement…";

  try {
    const { Questions } = await loadQuestions();
    const questions = shuffleArray([...Questions]);
    const response = await fetch(`${API_URL}/users`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ firstname, email, website }),
    });

    if (!response.ok) throw new Error(`HTTP ${response.status}`);

    const user = await response.json();
    await leaveScreen(registration);
    startQuiz(questions, subjectLabel, user);
  } catch (error) {
    console.error("Erreur au démarrage du quiz", error);
    errorMessage.textContent = "Le quiz n’a pas pu démarrer. Réessaie dans un instant.";
  } finally {
    fields.disabled = false;
    submitButton.disabled = false;
    buttonLabel.textContent = "Commencer le quiz";
  }
}

function formatNumber(number) {
  return String(number).padStart(2, "0");
}

function formatAnswer(answer) {
  return answer.replace(/^[A-Z]\.\s+/, "");
}

function setStatus(element, label, isCorrect) {
  element.hidden = false;
  element.classList.add(isCorrect ? "status-correct" : "status-wrong");
  element.querySelector(".status-icon").textContent = isCorrect ? "✓" : "×";
  element.querySelector(".status-label").textContent = label;
}

function createChoice(answer, index) {
  const choice = cloneTemplate("answer-template");
  choice.style.setProperty("--order", index);
  choice.querySelector("input").value = index;
  choice.querySelector(".answer-letter").textContent = String.fromCharCode(65 + index);
  choice.querySelector(".answer-text").textContent = formatAnswer(answer);
  return choice;
}

function startQuiz(questions, subject, user) {
  const quiz = cloneTemplate("quiz-template");
  const progress = quiz.querySelector(".progress");
  const timer = quiz.querySelector(".question-timer");
  const timerRing = timer.querySelector(".timer-ring");
  const timerValue = timer.querySelector(".timer-value");
  const counter = quiz.querySelector(".question-counter");
  const slot = quiz.querySelector(".question-slot");
  const answers = [];

  quiz.querySelector(".quiz-subject").textContent = subject;
  progress.setAttribute("aria-valuemax", questions.length);
  app.replaceChildren(quiz);
  showQuestion();

  function showQuestion() {
    const index = answers.length;
    const question = questions[index];
    const card = cloneTemplate("question-template");
    const title = card.querySelector(".question-title");
    const fieldset = card.querySelector(".answers");
    const submitButton = card.querySelector("button");
    const buttonLabel = submitButton.querySelector(".button-label");
    const countdown = submitButton.querySelector(".advance-countdown");
    const choices = question.answers.map(createChoice);

    counter.textContent = `${formatNumber(index + 1)} / ${formatNumber(questions.length)}`;
    title.textContent = question.question;
    fieldset.append(...choices);
    slot.replaceChildren(card);
    window.scrollTo(0, 0);
    title.focus({ preventScroll: true });

    const startedAt = performance.now();
    const deadline = startedAt + QUESTION_TIME * 1000;
    let secondsLeft = -1;
    let advanceAt = null;
    let advancing = false;
    const interval = window.setInterval(updateTimer, 200);
    updateTimer();

    fieldset.addEventListener("change", () => {
      submitButton.disabled = false;
    });

    card.addEventListener("submit", (event) => {
      event.preventDefault();
      if (advanceAt !== null) {
        advance();
        return;
      }

      const selected = fieldset.querySelector("input:checked");
      if (!selected) return;

      const now = performance.now();
      if (now >= deadline) {
        updateTimer();
      } else {
        recordAnswer(Number(selected.value), now);
      }
    });

    function updateTimer() {
      const now = performance.now();

      if (advanceAt !== null) {
        if (now >= advanceAt) {
          advance();
        } else {
          const nextSeconds = Math.ceil((advanceAt - now) / 1000);
          const label = `(${nextSeconds} s)`;
          if (countdown.textContent !== label) countdown.textContent = label;
        }
        return;
      }

      const remaining = Math.max(0, Math.ceil((deadline - now) / 1000));
      if (remaining === secondsLeft) return;

      secondsLeft = remaining;
      timerValue.textContent = `${formatNumber(remaining)} s`;
      timerRing.style.setProperty("--remaining-time", `${(remaining / QUESTION_TIME) * 100}%`);
      timer.classList.toggle("timer-warning", remaining <= 10);

      if (remaining === 0) recordAnswer(null, now);
    }

    function recordAnswer(selectedIndex, now) {
      const timedOut = selectedIndex === null;
      const userAnswer = timedOut ? null : question.answers[selectedIndex];
      const isCorrect = userAnswer === question.correct;
      const delay = timedOut ? TIMEOUT_FEEDBACK_TIME : ANSWER_FEEDBACK_TIME;
      advanceAt = now + delay;

      answers.push({
        questionIndex: index,
        questionText: question.question,
        userAnswer,
        correctAnswer: question.correct,
        isCorrect,
        timeSpentMs: Math.round(now - startedAt),
      });

      const correctIndex = question.answers.indexOf(question.correct);
      const correctChoice = choices[correctIndex];
      correctChoice.classList.add("is-correct");
      setStatus(correctChoice.querySelector(".answer-status"), isCorrect ? "Correct" : "Bonne réponse", true);

      if (isCorrect) {
        correctChoice.classList.add("has-shimmer");
      } else if (!timedOut) {
        const wrongChoice = choices[selectedIndex];
        wrongChoice.classList.add("is-wrong");
        setStatus(wrongChoice.querySelector(".answer-status"), "Incorrect", false);
      }

      const moveFocus = fieldset.contains(document.activeElement);
      fieldset.disabled = true;
      card.classList.add("is-answered");
      timer.classList.remove("timer-warning");
      progress.setAttribute("aria-valuenow", answers.length);
      progress.style.setProperty("--progress", answers.length / questions.length);

      card.querySelector(".feedback-title").textContent =
        timedOut ? "Temps écoulé" : isCorrect ? "Bonne réponse !" : "Réponse incorrecte";
      if (!isCorrect) {
        card.querySelector(".feedback-detail").textContent = `Bonne réponse · ${formatAnswer(question.correct)}`;
      }

      buttonLabel.textContent = answers.length === questions.length ? "Voir le bilan" : "Question suivante";
      countdown.textContent = `(${delay / 1000} s)`;
      submitButton.disabled = false;
      if (moveFocus) submitButton.focus();
    }

    async function advance() {
      if (advancing) return;
      advancing = true;
      window.clearInterval(interval);
      submitButton.disabled = true;
      card.classList.add("is-leaving");

      const exit = card.getAnimations().find((animation) => animation.animationName === "question-out");
      await exit?.finished.catch(() => {});

      if (answers.length === questions.length) {
        showResults(subject, user, answers);
      } else {
        showQuestion();
      }
    }
  }
}

function showResults(subject, user, answers) {
  const results = cloneTemplate("results-template");
  const score = answers.filter((answer) => answer.isCorrect).length;
  const total = answers.length;
  const percent = Math.round((score / total) * 100);
  const review = results.querySelector(".review-list");
  let streak = 0;
  let bestStreak = 0;
  let totalTimeMs = 0;

  for (const answer of answers) {
    streak = answer.isCorrect ? streak + 1 : 0;
    bestStreak = Math.max(streak, bestStreak);
    totalTimeMs += answer.timeSpentMs;
    review.append(createReviewRow(answer));
  }

  const averageTime = (totalTimeMs / total / 1000).toFixed(1).replace(".", ",");
  results.querySelector(".results-subject").textContent = subject;
  results.querySelector(".correct-count").textContent = `${score} / ${total}`;
  results.querySelector(".best-streak").textContent = bestStreak;
  results.querySelector(".average-time").textContent = `${averageTime} s`;
  results.querySelector(".review-count").textContent = `${total} question${total === 1 ? "" : "s"}`;
  results.querySelector(".score-accessible").textContent = `${percent} %`;
  const replayButton = results.querySelector(".replay-button");
  replayButton.addEventListener("click", async () => {
    replayButton.disabled = true;
    await leaveScreen(results);
    showScreen(registration);
  });

  showScreen(results);
  animateScore(results.querySelector(".score-percent"), percent);
  saveResults(user, score, answers, results.querySelector(".saving-message"));
}

function createReviewRow(answer) {
  const row = cloneTemplate("review-template");
  const timedOut = answer.userAnswer === null;
  row.style.setProperty("--order", Math.min(answer.questionIndex, 8));
  row.querySelector(".review-number").textContent = formatNumber(answer.questionIndex + 1);
  row.querySelector(".review-question").textContent = answer.questionText;
  row.querySelector(".review-correct strong").textContent = formatAnswer(answer.correctAnswer);

  const chosen = row.querySelector(".review-chosen");
  chosen.hidden = timedOut || answer.isCorrect;
  if (!chosen.hidden) chosen.querySelector("strong").textContent = formatAnswer(answer.userAnswer);

  const statusLabel = timedOut ? "Temps écoulé" : answer.isCorrect ? "Correct" : "Incorrect";
  setStatus(row.querySelector(".review-status"), statusLabel, answer.isCorrect);
  return row;
}

function animateScore(display, percent) {
  if (percent === 0 || window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    display.textContent = `${percent} %`;
    return;
  }

  const start = performance.now();
  display.textContent = "0 %";

  function frame(now) {
    if (!display.isConnected) return;
    const progress = Math.min((now - start) / 700, 1);
    const eased = 1 - (1 - progress) ** 3;
    display.textContent = `${Math.round(eased * percent)} %`;
    if (progress < 1) window.requestAnimationFrame(frame);
  }

  window.requestAnimationFrame(frame);
}

async function saveResults(user, score, answers, message) {
  message.textContent = "Enregistrement en cours…";
  try {
    const response = await fetch(`${API_URL}/results`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        userId: user.id,
        score,
        totalQuestions: answers.length,
        answers,
      }),
    });

    if (!response.ok) throw new Error(`HTTP ${response.status}`);

    const { emailSent } = await response.json();
    message.textContent = emailSent
      ? `Résultat envoyé à ${user.email}.`
      : "Résultat enregistré, mais l’e-mail n’a pas pu être envoyé.";
    message.classList.add(emailSent ? "status-correct" : "status-wrong");
  } catch (error) {
    console.error("Erreur lors de l’enregistrement du résultat", error);
    message.textContent = "Le résultat n’a pas pu être enregistré.";
    message.classList.add("status-wrong");
  }
}
