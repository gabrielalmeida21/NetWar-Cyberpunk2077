// NET War — aba TUTORIAL: como cada parte do mod funciona (lista de tópicos + texto).
// Só apresentação. Linhas que começam com "## " são títulos; "• " são itens.
module NetWar.UI

import NetWar.*
import NetWar.Data.*

public abstract class NWTutorial {
  public static func Count() -> Int32 { return 13; }

  public static func Title(k: Int32) -> String {
    switch k {
      case 0: return NWL.T("Primeiros passos", "Getting started");
      case 1: return NWL.T("Mapa e território", "Map and territory");
      case 2: return NWL.T("Banco, RAM e rastreio", "Bank, RAM and trace");
      case 3: return NWL.T("A invasão", "The breach");
      case 4: return NWL.T("Backdoor (senha)", "Backdoor (password)");
      case 5: return NWL.T("Eye-Dee (arquivo)", "Eye-Dee (file)");
      case 6: return NWL.T("Zap (atacar o ICE)", "Zap (attack the ICE)");
      case 7: return NWL.T("Slide (passar pelo ICE)", "Slide (get past the ICE)");
      case 8: return NWL.T("Defesa contra o ICE", "Defense against the ICE");
      case 9: return NWL.T("Controlar (nó de controle)", "Control (control node)");
      case 10: return NWL.T("Escanear (sonar)", "Scan (sonar)");
      case 11: return "Daemons";
      default: return NWL.T("Arquiteturas e defesas", "Architectures and defenses");
    }
  }

  public static func Lines(k: Int32) -> array<String> {
    if NWL.IsEnglish() {
      return NWTutorial.LinesEn(k);
    }
    switch k {
      case 0: return [
        "## O que é o NET War",
        "Guerra territorial na NET: invada nós de corporações e gangues pelo mundo e mantenha o seu território.",
        "## Como entrar",
        "• Use o computador do seu apartamento: ao mirar nele aparece a opção \"NetWar\".",
        "• A rede continua andando com o tempo do jogo enquanto você está fora (até 7 dias).",
        "## O ciclo",
        "• No MAPA DA REDE, escolha um nó vizinho de um nó seu e faça o JACK-IN.",
        "• Desça a torre de andares até o Nó de Controle e tome o nó.",
        "• Nós seus rendem eddies por dia; as facções atacam os seus nós com o tempo.",
        "## Testes: minigame ou dado",
        "• Cada ação da invasão pode ser um minigame de habilidade ou o d10 do Cyberpunk RED.",
        "• Troque no botão TESTES, no canto inferior direito da tela da invasão.",
        "• Atributos, Interface e cyberdeck ajudam em cada minigame; o painel SEU NETRUNNER mostra como."
      ];
      case 1: return [
        "## Mapa",
        "• Clique num nó para ver dono, controle, andares, DV, ICE e a recompensa.",
        "• Só dá para invadir nós vizinhos de um nó seu. A Blackwall esconde andares e DV até ser escaneada.",
        "• ESCANEAR (2 RAM) revela o ICE escondido e o estilo da arquitetura do nó.",
        "## Zoom: MUNDO, REGIÃO e CIDADE",
        "• REGIÃO mostra só as regiões de cada nó; CIDADE mostra só os locais de cada região. A roda do mouse também dá zoom.",
        "• Dominar uma região dá +15% de controle no nó pai e −1 DV na invasão a ele; um local dá +5%.",
        "• Um local exige que a região dele já seja sua. Sub-nós que você não tomou seguem o dono do nó pai.",
        "## Facções",
        "• Arasaka, Militech, Kang Tao e Voodoo Boys atacam vizinhos com o tempo. A aba REGISTROS mostra tudo.",
        "• Zonas Blackwall são as mais perigosas: ser expulso lá fere o V de verdade."
      ];
      case 2: return [
        "## Banco NetWatch",
        "• Arquivos, recompensas e renda caem no banco do mod. Saque ou deposite na carteira do V pelo painel do mapa.",
        "• O banco paga as defesas dos seus nós. Ele fica congelado durante o bloqueio da Netwatch.",
        "## RAM",
        "• É a memória real do seu cyberdeck (a mesma do HUD) e se recupera sozinha.",
        "• Escanear gasta 2; daemons gastam RAM na invasão. Dominar Tóquio dá +2 RAM extra por jack-in.",
        "## Rastreio da Netwatch",
        "• Falhas, acertos do ICE e alguns modificadores sobem o rastreio; ele cai com o tempo.",
        "• Em 100% a Netwatch faz uma ofensiva contra os seus nós e bloqueia a rede por 24 horas.",
        "## Interface",
        "• Seu nível de netrunner no mod: 2 + INT/4 + raridade do cyberdeck (+2 com o Canto Mk.6) + bônus de nós.",
        "• Define as ações de NET por turno (2 a 5) e entra nos testes e minigames."
      ];
      case 3: return [
        "## A torre",
        "• Cada nó é uma torre: senhas, arquivos, Black ICE, caches de daemon e, no fim, o Nó de Controle.",
        "• Os 2 primeiros andares (lobby) só têm senha ou arquivo. Bifurcações deixam pegar o caminho da direita.",
        "## Turnos",
        "• Você tem algumas ações de NET por turno. ENCERRAR TURNO renova as ações, mas o Black ICE do andar ataca.",
        "• Senha e Black ICE ativos bloqueiam a descida.",
        "## Ações",
        "• ESCANEAR revela andares · BACKDOOR quebra senha · EYE-DEE baixa arquivo · ZAP ataca o ICE · SLIDE passa pelo ICE",
        "• CAMUFLAR reduz o ataque do ICE e o rastreio · CONTROLAR toma o nó · DESCONECTAR sai com o progresso",
        "## Cuidado",
        "• Desconectar com ICE ativo dá a ele um último ataque. HP da sessão zerado = expulso (perde os daemons coletados).",
        "• Cada ICE tem um efeito especial ao acertar (prender, queimar RAM, derrezzar daemon...), mostrado no andar."
      ];
      case 4: return [
        "## Objetivo",
        "Montar a SEQUÊNCIA pedida, em ordem, dentro do BUFFER.",
        "## Regras",
        "• A 1ª escolha é na linha de cima. Depois alterne: coluna da última escolha, linha da última escolha.",
        "• A linha ou coluna ativa fica destacada. O tempo só começa na 1ª escolha.",
        "• Falha (tempo esgotado ou buffer cheio) dá rastreio.",
        "## Dicas na grade",
        "• Amarelo (Inteligência): casas com o próximo código. Cuidado: podem levar a um beco sem saída.",
        "• Vermelho (Canto Mk.6): a próxima casa do caminho que fecha a sequência mais rápido.",
        "## O que ajuda",
        "• Interface: sequência menor · Hab. técnica: buffer maior · Inteligência: dicas · Cyberdeck: tempo",
        "• Verme (daemon): dicas em todos os passos"
      ];
      case 5: return [
        "## Objetivo",
        "Remontar o cabeçalho do arquivo, do INÍCIO ao FIM.",
        "## Regras",
        "• Cada bloco começa com o caractere em que o anterior terminou: 4A, A7, 7E.",
        "• O espaço amarelo mostra com que caractere o próximo bloco precisa começar (ex.: A?).",
        "• Blocos CORROMPIDOS começam certo, mas terminam num caractere que não continua nenhum bloco.",
        "• Se dois blocos servem, olhe o último caractere: o certo continua a corrente ou termina no FIM.",
        "• O 3º erro corrompe o arquivo (falha).",
        "## O que ajuda",
        "• Interface: corrente menor · Inteligência: próximo bloco destacado · Hab. técnica: erros sem rastreio",
        "• Sangue-frio 8+: o tempo só corre depois do 1º clique · Cyberdeck: blocos já encaixados"
      ];
      case 6: return [
        "## Objetivo",
        "Acertar o Black ICE no momento certo.",
        "## Regras",
        "• Um marcador gira no anel. Ataque (clique ou ESPAÇO) quando ele estiver na zona.",
        "• Vermelho = crítico (dano máximo) · Amarelo = acerto · Fora = erro (rastreio).",
        "• Se as voltas acabarem sem ataque, conta como erro.",
        "## O que ajuda",
        "• Reflexos: zona maior · Defesa do ICE: zona menor · Velocidade do ICE: anel mais rápido",
        "• Cyberdeck: mais voltas · Canto Mk.6: +1 volta · Lâmina: segunda zona · Interface: mais dano"
      ];
      case 7: return [
        "## Objetivo",
        "Passar pelo Black ICE sem derrubá-lo: atravessar o corredor até a SAÍDA.",
        "## Regras",
        "• Avance uma faixa por vez (clique ou ESPAÇO). Você fica sempre na coluna do meio.",
        "• Em cada faixa um feixe vai e volta. Se o feixe da sua faixa encostar em você, o ICE te vê.",
        "• Entre quando o feixe estiver longe e saia antes que ele volte.",
        "• Falha (visto ou tempo esgotado): rastreio e o ICE ataca na hora.",
        "## O que ajuda",
        "• Interface: menos faixas · Sangue-frio: feixes mais lentos · Inteligência: feixes mais estreitos",
        "• Percepção do ICE: feixes maiores e mais rápidos · Cyberdeck/Canto: tempo · Camuflagem/Fantasma: feixes piscam"
      ];
      case 8: return [
        "## Quando acontece",
        "No fim do turno, se houver Black ICE ativo no andar, ele ataca e você se defende.",
        "## Regras",
        "• Clique nos códigos na ordem mostrada antes do tempo acabar (o tempo já começa correndo).",
        "• Todos certos = esquiva total. Cada erro deixa passar parte do golpe.",
        "• O efeito especial do ICE só pega se você errar metade ou mais.",
        "• O Espelho anula o ataque sem minigame.",
        "## O que ajuda",
        "• Reflexos: mais tempo · Interface 10+: um código a menos · Constituição: menos dano",
        "• Ataque do ICE: sequência maior · Cyberdeck/Canto: um pouco mais de tempo"
      ];
      case 9: return [
        "## Objetivo",
        "Ligar a FONTE (esquerda) ao NÚCLEO (direita) para tomar o nó.",
        "## Regras",
        "• Clique numa peça para girá-la um quarto de volta. Peças com energia acendem em azul.",
        "• Qualquer rota que ligue os dois vale. O tempo começa no 1º giro.",
        "• Falha (tempo esgotado) dá rastreio.",
        "## O que ajuda",
        "• Interface: grade menor · Hab. técnica: peças já travadas no lugar (FIXA) · Inteligência: casas do caminho em amarelo",
        "• Cyberdeck/Canto: tempo · Sobrecarga: +6 s"
      ];
      case 10: return [
        "## Objetivo",
        "Revelar o máximo da torre com o sonar.",
        "## Regras",
        "• A cada pulso o eco azul se fecha. Clique (ou ESPAÇO) quando ele passar pela faixa amarela.",
        "• Vermelho = perfeito (2 pontos) · Amarelo = bom (1) · Fora = erro (0).",
        "• Errar tudo revela a base (o andar atual + 3). Mais pontos revelam mais; a meta revela a torre inteira.",
        "• Não tem falha nem rastreio.",
        "## O que ajuda",
        "• Reflexos: faixa maior · Interface/Cyberdeck: eco mais lento · Inteligência: meta menor · Canto Mk.6: +1 pulso"
      ];
      case 11: return [
        "## O que são",
        "Programas que você acha em caches de daemon e ao dominar nós (o Fragmento de IA só sai na Blackwall).",
        "## Como usar",
        "• Equipe nos slots da aba DAEMONS. Na invasão, ativar é ação livre e gasta RAM do deck.",
        "• Ser expulso perde os daemons coletados naquela sessão.",
        "## Raridade",
        "• O efeito é o mesmo em toda raridade; a raridade só reduz o custo de RAM.",
        "• 2 cópias repetidas sobem uma raridade; num lendário, cada cópia vira €$ 1.000 no banco.",
        "## Efeitos",
        "• Lâmina: Zap +3 · Espelho: anula um acerto do ICE · Verme: senhas mais fáceis · Fantasma: rastreio zero no andar",
        "• Sobrecarga: +1 ação · Âncora: evita a expulsão · Fragmento de IA: +3 Interface, mas +2 de rastreio por turno"
      ];
      default: return [
        "## Inteligência",
        "• Escanear um nó revela o estilo da arquitetura; invadir revela andares, profundidade e modificadores.",
        "• A inteligência fica velha quando o nó troca de dono.",
        "## Estilos e modificadores",
        "• Cada facção monta torres diferentes (Arasaka funda, Militech com senhas, Vodu com bifurcações...).",
        "• Modificadores sorteados mudam a invasão: senhas rotativas, câmara fria, névoa densa, eco de rastreio.",
        "## Defesas dos seus nós",
        "• 3 camadas por nó, pagas pelo Banco NetWatch:",
        "• Senha (+2 na defesa) · Black ICE (+1 e absorve um ataque) · Isca (35% de desviar o ataque)",
        "• Remover não devolve os eddies. Perder o nó apaga as camadas."
      ];
    }
  }

  private static func LinesEn(k: Int32) -> array<String> {
    switch k {
      case 0: return [
        "## What NET War is",
        "Territorial war on the NET: breach corporate and gang nodes around the world and hold your territory.",
        "## How to get in",
        "• Use the computer in your apartment: aiming at it shows the \"NetWar\" option.",
        "• The network keeps moving with game time while you're away (up to 7 days).",
        "## The loop",
        "• On the NETWORK MAP, pick a node next to one of yours and JACK-IN.",
        "• Go down the tower of floors to the Control Node and take the node.",
        "• Your nodes yield eddies every day; factions attack your nodes over time.",
        "## Checks: minigame or die",
        "• Every breach action can be a skill minigame or the Cyberpunk RED d10.",
        "• Switch it with the CHECKS button in the bottom right corner of the breach screen.",
        "• Attributes, Interface and cyberdeck help in each minigame; the YOUR NETRUNNER panel shows how."
      ];
      case 1: return [
        "## Map",
        "• Click a node to see owner, control, floors, DV, ICE and the reward.",
        "• You can only breach nodes next to one of yours. The Blackwall hides floors and DV until scanned.",
        "• SCAN (2 RAM) reveals hidden ICE and the node's architecture style.",
        "## Zoom: WORLD, REGION and CITY",
        "• REGION shows only each node's regions; CITY shows only each region's sites. The mouse wheel also zooms.",
        "• Taking a region gives +15% control over the parent node and −1 DV when breaching it; a site gives +5%.",
        "• A site requires its region to be yours. Sub-nodes you haven't taken follow the parent node's owner.",
        "## Factions",
        "• Arasaka, Militech, Kang Tao and Voodoo Boys attack neighbors over time. The LOGS tab shows everything.",
        "• Blackwall zones are the most dangerous: getting kicked out there hurts V for real."
      ];
      case 2: return [
        "## NetWatch Bank",
        "• Files, rewards and income go into the mod's bank. Withdraw or deposit to V's wallet from the map panel.",
        "• The bank pays for your nodes' defenses. It's frozen during the Netwatch lockout.",
        "## RAM",
        "• It's your cyberdeck's real memory (the same as the HUD) and it recovers on its own.",
        "• Scanning costs 2; daemons spend RAM during a breach. Taking Tokyo gives +2 extra RAM per jack-in.",
        "## Netwatch trace",
        "• Failures, ICE hits and some modifiers raise the trace; it drops over time.",
        "• At 100% Netwatch launches an offensive against your nodes and locks the network for 24 hours.",
        "## Interface",
        "• Your netrunner level in the mod: 2 + INT/4 + cyberdeck rarity (+2 with the Canto Mk.6) + node bonuses.",
        "• It sets your NET actions per turn (2 to 5) and goes into checks and minigames."
      ];
      case 3: return [
        "## The tower",
        "• Each node is a tower: passwords, files, Black ICE, daemon caches and, at the end, the Control Node.",
        "• The first 2 floors (lobby) only have passwords or files. Forks let you take the right-hand path.",
        "## Turns",
        "• You get a few NET actions per turn. END TURN refreshes them, but the floor's Black ICE attacks.",
        "• An active password or Black ICE blocks the way down.",
        "## Actions",
        "• SCAN reveals floors · BACKDOOR breaks passwords · EYE-DEE downloads files · ZAP attacks ICE · SLIDE gets past ICE",
        "• CLOAK lowers ICE attacks and trace · CONTROL takes the node · DISCONNECT leaves with your progress",
        "## Careful",
        "• Disconnecting with active ICE gives it one last attack. Session HP at zero = kicked out (collected daemons lost).",
        "• Each ICE has a special effect when it hits (hold, burn RAM, derezz a daemon...), shown on the floor."
      ];
      case 4: return [
        "## Goal",
        "Build the requested SEQUENCE, in order, inside the BUFFER.",
        "## Rules",
        "• The 1st pick is on the top row. Then alternate: column of the last pick, row of the last pick.",
        "• The active row or column is highlighted. The clock starts on the 1st pick.",
        "• Failing (time out or full buffer) adds trace.",
        "## Hints on the grid",
        "• Yellow (Intelligence): cells with the next code. Careful: they can lead to a dead end.",
        "• Red (Canto Mk.6): the next cell of the path that completes the sequence fastest.",
        "## What helps",
        "• Interface: shorter sequence · Technical Ability: bigger buffer · Intelligence: hints · Cyberdeck: time",
        "• Worm (daemon): hints on every step"
      ];
      case 5: return [
        "## Goal",
        "Rebuild the file header, from START to END.",
        "## Rules",
        "• Each block starts with the character the previous one ended with: 4A, A7, 7E.",
        "• The yellow slot shows which character the next block must start with (e.g. A?).",
        "• CORRUPTED blocks start right but end on a character that continues no block.",
        "• If two blocks fit, check the last character: the right one continues the chain or ends at END.",
        "• The 3rd error corrupts the file (fail).",
        "## What helps",
        "• Interface: shorter chain · Intelligence: next block highlighted · Technical Ability: errors without trace",
        "• Cool 8+: the clock only runs after the 1st click · Cyberdeck: blocks already placed"
      ];
      case 6: return [
        "## Goal",
        "Hit the Black ICE at the right moment.",
        "## Rules",
        "• A marker spins around the ring. Strike (click or SPACE) when it's inside the zone.",
        "• Red = critical (max damage) · Yellow = hit · Outside = miss (trace).",
        "• If the laps run out without a strike, it counts as a miss.",
        "## What helps",
        "• Reflexes: bigger zone · ICE Defense: smaller zone · ICE Speed: faster ring",
        "• Cyberdeck: more laps · Canto Mk.6: +1 lap · Blade: second zone · Interface: more damage"
      ];
      case 7: return [
        "## Goal",
        "Get past the Black ICE without taking it down: cross the corridor to the EXIT.",
        "## Rules",
        "• Move up one lane at a time (click or SPACE). You always stay in the middle column.",
        "• A beam sweeps back and forth in each lane. If the beam in your lane touches you, the ICE sees you.",
        "• Step in when the beam is far away and get out before it comes back.",
        "• Failing (seen or time out): trace, and the ICE attacks right away.",
        "## What helps",
        "• Interface: fewer lanes · Cool: slower beams · Intelligence: narrower beams",
        "• ICE Perception: bigger, faster beams · Cyberdeck/Canto: time · Cloak/Ghost: beams blink"
      ];
      case 8: return [
        "## When it happens",
        "At the end of the turn, if there's active Black ICE on the floor, it attacks and you defend.",
        "## Rules",
        "• Click the codes in the order shown before time runs out (the clock starts right away).",
        "• All correct = full dodge. Each mistake lets part of the blow through.",
        "• The ICE's special effect only lands if you miss half or more.",
        "• Mirror negates the attack without the minigame.",
        "## What helps",
        "• Reflexes: more time · Interface 10+: one fewer code · Body: less damage",
        "• ICE Attack: longer sequence · Cyberdeck/Canto: a little more time"
      ];
      case 9: return [
        "## Goal",
        "Link the SOURCE (left) to the CORE (right) to take the node.",
        "## Rules",
        "• Click a piece to rotate it a quarter turn. Powered pieces light up blue.",
        "• Any route that links both counts. The clock starts on the 1st turn.",
        "• Failing (time out) adds trace.",
        "## What helps",
        "• Interface: smaller grid · Technical Ability: pieces already locked in place (FIXED) · Intelligence: path cells in yellow",
        "• Cyberdeck/Canto: time · Overload: +6 s"
      ];
      case 10: return [
        "## Goal",
        "Reveal as much of the tower as you can with the sonar.",
        "## Rules",
        "• Each pulse sends a blue echo closing in. Click (or SPACE) when it crosses the yellow band.",
        "• Red = perfect (2 points) · Yellow = good (1) · Outside = miss (0).",
        "• Missing everything reveals the base (current floor + 3). More points reveal more; the goal reveals the whole tower.",
        "• There's no failure and no trace.",
        "## What helps",
        "• Reflexes: wider band · Interface/Cyberdeck: slower echo · Intelligence: lower goal · Canto Mk.6: +1 pulse"
      ];
      case 11: return [
        "## What they are",
        "Programs found in daemon caches and by taking nodes (the AI Fragment only drops in the Blackwall).",
        "## How to use them",
        "• Equip them in the DAEMONS tab slots. In a breach, activating is a free action that spends deck RAM.",
        "• Getting kicked out loses the daemons collected in that session.",
        "## Rarity",
        "• The effect is the same at every rarity; rarity only lowers the RAM cost.",
        "• 2 duplicate copies raise the rarity by one; on a legendary, each copy becomes €$ 1,000 in the bank.",
        "## Effects",
        "• Blade: Zap +3 · Mirror: negates one ICE hit · Worm: easier passwords · Ghost: zero trace on the floor",
        "• Overload: +1 action · Anchor: prevents being kicked out · AI Fragment: +3 Interface, but +2 trace per turn"
      ];
      default: return [
        "## Intel",
        "• Scanning a node reveals its architecture style; breaching reveals floors, depth and modifiers.",
        "• Intel goes stale when the node changes hands.",
        "## Styles and modifiers",
        "• Each faction builds different towers (deep Arasaka, password-heavy Militech, forking Voodoo...).",
        "• Rolled modifiers change the breach: rotating passwords, cold chamber, dense fog, trace echo.",
        "## Your nodes' defenses",
        "• 3 layers per node, paid from the NetWatch Bank:",
        "• Password (+2 defense) · Black ICE (+1 and absorbs one attack) · Decoy (35% chance to divert the attack)",
        "• Removing doesn't refund the eddies. Losing the node wipes the layers."
      ];
    }
  }
}

public class NWTutorialView extends IScriptable {
  private let sys: wref<NetWarSystem>;
  private let owner: wref<NetWarMapPopup>;
  private let root: wref<inkCanvas>;
  private let dynamic: wref<inkCanvas>;
  private let selected: Int32;
  // Treino: o mesmo painel da invasão, deslocado para a área do texto.
  private let mini: ref<NWMiniPanel>;

  public static func Create(sys: wref<NetWarSystem>, owner: wref<NetWarMapPopup>, parent: ref<inkCompoundWidget>) -> ref<NWTutorialView> {
    let view = new NWTutorialView();
    view.sys = sys;
    view.owner = owner;
    view.Build(parent);
    return view;
  }

  public func SetVisible(visible: Bool) -> Void {
    this.root.SetVisible(visible);
  }

  private func Build(parent: ref<inkCompoundWidget>) -> Void {
    let r = NWInk.Canvas(parent, n"tutorial_view", 0.0, 0.0, 1920.0, 1080.0);
    this.root = r;
    NWInk.Rect(r, 0.0, 0.0, 1920.0, 1080.0, NWTheme.Bg(), 0.97);
    let gx = 0.0;
    while gx < 1920.0 {
      NWInk.Rect(r, gx, 0.0, 1.0, 1080.0, NWTheme.Red(), 0.045);
      gx += 48.0;
    }
    let gy = 0.0;
    while gy < 1080.0 {
      NWInk.Rect(r, 0.0, gy, 1920.0, 1.0, NWTheme.Red(), 0.045);
      gy += 48.0;
    }
    NWInk.Rect(r, 0.0, 0.0, 1920.0, 96.0, NWTheme.Bg(), 0.92);
    NWInk.Rect(r, 0.0, 95.0, 1920.0, 1.0, NWTheme.Red(), 0.35);
    let title = NWInk.Text(r, 48.0, 14.0, NWL.T("NET::ACESSO", "NET::ACCESS"), 34, NWTheme.Red(), n"Semi-Bold");
    NWTheme.BindGameRed(title);
    NWInk.Text(r, 48.0, 56.0, NWL.T("TERMINAL DOMÉSTICO // TUTORIAL", "HOME TERMINAL // TUTORIAL"), 16, NWTheme.Muted(), n"Medium");
    this.Tab(r, n"tab_map", 400.0, NWL.T("MAPA DA REDE", "NETWORK MAP"), false);
    this.Tab(r, n"tab_arch", 628.0, NWL.T("ARQUITETURAS", "ARCHITECTURES"), false);
    this.Tab(r, n"tab_daemons", 846.0, "DAEMONS", false);
    this.Tab(r, n"tab_logs", 1064.0, NWL.T("REGISTROS", "LOGS"), false);
    this.Tab(r, n"", 1282.0, "TUTORIAL", true);

    NWInk.Text(r, 48.0, 116.0, "TUTORIAL", 40, NWTheme.Cyan(), n"Semi-Bold");
    NWInk.Text(r, 48.0, 166.0, NWL.T("Como cada parte do NET War funciona. Escolha um tópico à esquerda.", "How each part of NET War works. Pick a topic on the left."), 18, NWTheme.Muted(), n"Medium");
    this.dynamic = NWInk.Canvas(r, n"tutorial_dynamic", 0.0, 0.0, 1920.0, 1080.0);
    let practiceHost = NWInk.Canvas(r, n"practice_host", 300.0, 80.0, 1920.0, 1080.0);
    this.mini = NWMiniPanel.Create(this.sys, practiceHost);
    this.mini.SetTutorialHost(this);
  }

  public func IsShown() -> Bool {
    return this.root.IsVisible();
  }

  // Tópicos de minigame → tipo do treino (1 Backdoor … 7 Escanear); 0 = tópico sem minigame.
  private func PracticeKind(topic: Int32) -> Int32 {
    return topic >= 4 && topic <= 10 ? topic - 3 : 0;
  }

  // ESPAÇO (Zap, Slide, Escanear) chega pelo popup do mapa.
  public func HandleMini(name: String) -> Void {
    this.mini.HandleClick(name);
  }

  private func Tab(r: ref<inkCanvas>, name: CName, x: Float, label: String, active: Bool) -> Void {
    let w = x == 400.0 ? 220.0 : 210.0;
    if active {
      NWInk.Rect(r, x, 24.0, w, 48.0, NWTheme.Red(), 1.0);
      NWInk.Text(r, x + 24.0, 33.0, label, 22, NWTheme.Bg(), n"Semi-Bold");
    } else {
      NWInk.Frame(r, x, 24.0, w, 48.0, NWTheme.Red(), 0.45);
      NWInk.Text(r, x + 24.0, 33.0, label, 22, NWTheme.Text(), n"Semi-Bold");
    }
    if NotEquals(name, n"") {
      let hit = NWInk.HitArea(r, name, x, 24.0, w, 48.0);
      hit.RegisterToCallback(n"OnRelease", this, n"OnRelease");
    }
  }

  public func Refresh() -> Void {
    let d = this.dynamic;
    d.RemoveAllChildren();
    // Lista de tópicos.
    let k = 0;
    while k < NWTutorial.Count() {
      let y = 214.0 + Cast<Float>(k) * 50.0;
      let on = k == this.selected;
      NWInk.Rect(d, 48.0, y, 500.0, 44.0, on ? NWTheme.Cyan() : NWTheme.Text(), on ? 0.16 : 0.04);
      NWInk.Frame(d, 48.0, y, 500.0, 44.0, on ? NWTheme.Cyan() : NWTheme.Red(), on ? 1.0 : 0.25);
      NWInk.Text(d, 64.0, y + 10.0, NWTutorial.Title(k), 19, on ? NWTheme.Cyan() : NWTheme.Text(), n"Semi-Bold");
      let hit = NWInk.HitArea(d, StringToName(s"help_\(k)"), 48.0, y, 500.0, 44.0);
      hit.RegisterToCallback(n"OnRelease", this, n"OnRelease");
      k += 1;
    }
    // Texto do tópico.
    NWInk.Panel(d, 580.0, 214.0, 1292.0, 800.0, NWTheme.Cyan(), 0.35);
    NWInk.Text(d, 612.0, 230.0, NWText.Upper(NWTutorial.Title(this.selected)), 30, NWTheme.Cyan(), n"Semi-Bold");
    this.mini.Draw();
    let y = 286.0;
    let sys = this.sys;
    let kind = this.PracticeKind(this.selected);
    if kind > 0 && !sys.HasMiniGame() {
      NWInk.Rect(d, 612.0, 940.0, 340.0, 52.0, NWTheme.Cyan(), 0.15);
      NWInk.Frame(d, 612.0, 940.0, 340.0, 52.0, NWTheme.Cyan(), 1.0);
      NWInk.Text(d, 630.0, 951.0, NWL.T("PRATICAR ESTE MINIGAME", "PRACTICE THIS MINIGAME"), 22, NWTheme.Cyan(), n"Semi-Bold");
      let practice = NWInk.HitArea(d, n"practice", 612.0, 940.0, 340.0, 52.0);
      practice.RegisterToCallback(n"OnRelease", this, n"OnRelease");
      NWInk.Text(d, 972.0, 944.0, NWL.T("Treino: seus atributos e equipamento reais, sem rastreio, dano nem recompensa.", "Practice: your real attributes and gear, no trace, damage or reward."), 15, NWTheme.Muted(), n"Medium");
      let last = sys.GetMiniLastText();
      if StrBeginsWith(last, "TREINO") || StrBeginsWith(last, "PRACTICE") {
        NWInk.Text(d, 972.0, 966.0, last, 18, NWTheme.Yellow(), n"Semi-Bold");
      }
    }
    for line in NWTutorial.Lines(this.selected) {
      if StrBeginsWith(line, "## ") {
        y += 10.0;
        NWInk.Text(d, 612.0, y, NWText.Upper(StrMid(line, 3, StrLen(line) - 3)), 18, NWTheme.Yellow(), n"Semi-Bold");
        y += 32.0;
      } else {
        NWInk.Text(d, 612.0, y, line, 18, NWTheme.Text(), n"Medium");
        y += 30.0;
      }
    }
  }

  protected cb func OnRelease(evt: ref<inkPointerEvent>) -> Bool {
    if !evt.IsAction(n"click") {
      return false;
    }
    let name = NameToString(evt.GetTarget().GetName());
    if Equals(name, "practice") {
      let msg = this.sys.StartPractice(this.PracticeKind(this.selected));
      this.sys.PlayUISound(StrLen(msg) == 0 ? NWSound.Select() : NWSound.HackFail());
      this.Refresh();
      return true;
    }
    if StrBeginsWith(name, "help_") {
      // Trocar de tópico encerra um treino aberto.
      if this.sys.IsPractice() {
        this.sys.AbortMiniGame();
      }
      this.selected = Clamp(StringToInt(StrAfterLast(name, "_")), 0, NWTutorial.Count() - 1);
      this.sys.PlayUISound(NWSound.Select());
      this.Refresh();
      return true;
    }
    this.sys.PlayUISound(NWSound.Select());
    if Equals(name, "tab_map") { this.owner.ShowMap(); }
    if Equals(name, "tab_arch") { this.owner.ShowArchitectures(-1); }
    if Equals(name, "tab_daemons") { this.owner.ShowDaemons(); }
    if Equals(name, "tab_logs") { this.owner.ShowLogs(); }
    return true;
  }
}
