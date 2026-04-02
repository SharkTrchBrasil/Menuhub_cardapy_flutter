import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:totem/models/order.dart';
import 'package:totem/pages/order/order_help_topic_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:totem/cubit/orders_cubit.dart';

class OrderHelpPage extends StatefulWidget {
  final Order order;

  const OrderHelpPage({super.key, required this.order});

  @override
  State<OrderHelpPage> createState() => _OrderHelpPageState();
}

class _OrderHelpPageState extends State<OrderHelpPage> {
  late Order _currentOrder;
  bool _hasJustConfirmed = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersCubit, OrdersState>(
      builder: (context, state) {
        // Sync order from state
        final updatedOrder = state.orders.where((o) => o.id == _currentOrder.id).firstOrNull;
        if (updatedOrder != null) {
          _currentOrder = updatedOrder;
        }

        final isDispatched = _currentOrder.lastStatus.toUpperCase() == 'DISPATCHED';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios,
                color: Colors.black,
                size: 20,
              ),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              'AJUDA COM PEDIDO',
              style: TextStyle(
                color: Color(0xFF3F3E3E),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            centerTitle: true,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.receipt_long, color: Colors.black, size: 20),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildOrderSummaryCard(context),
                
                if (isDispatched && !_hasJustConfirmed)
                  _buildConfirmArrivalCard(context),
                
                if (_hasJustConfirmed)
                  _buildJustConfirmedWidget(context),

                const SizedBox(height: 24),
                _buildTopicsSection(context),
                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderSummaryCard(BuildContext context) {
    final dateFormat = DateFormat("dd 'de' MMMM", 'pt_BR');
    final dateStr = dateFormat.format(_currentOrder.createdAt.toLocal());
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStoreAvatar(_currentOrder.merchant.logo, 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentOrder.merchant.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3F3E3E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF717171),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Colors.grey.shade100),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total com entrega',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF717171),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${NumberFormat.simpleCurrency(locale: 'pt_BR').format(_currentOrder.totalAmount)} / ${_currentOrder.items.length} itens',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3F3E3E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildStatusBanner(),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final dateFormat = DateFormat('HH:mm');
    final timeStr = dateFormat.format(
        (_currentOrder.closedAt ?? _currentOrder.updatedAt).toLocal()
    );

    // 1. CANCELADO PELO SISTEMA (TIMEOUT)
    if (_currentOrder.isSystemCancelled) {
      return _buildStatusCapsule(
        icon: Icons.cancel,
        iconColor: Colors.black,
        backgroundColor: const Color(0xFFF7F7F7),
        text: 'A loja não confirmou seu pedido e ele foi cancelado.',
        isBottom: true,
      );
    }

    // 2. CANCELADO GERAL (COM MOTIVO OU HORÁRIO)
    if (_currentOrder.lastStatus.toUpperCase() == 'CANCELED' || _currentOrder.isCancelled) {
      return _buildStatusCapsule(
        icon: Icons.cancel,
        iconColor: Colors.black,
        backgroundColor: const Color(0xFFF7F7F7),
        text: 'Pedido cancelado às $timeStr',
        isBottom: true,
      );
    }

    // 3. CONCLUÍDO
    if (_currentOrder.isConcluded) {
      return _buildStatusCapsule(
        icon: Icons.check_circle,
        iconColor: const Color(0xFF2E7D32),
        backgroundColor: const Color(0xFFF7F7F7),
        text: 'Pedido concluído às $timeStr',
        isBottom: true,
      );
    }

    // 4. EM ANDAMENTO / REALIZADO
    final isPending = _currentOrder.lastStatus.toUpperCase() == 'PENDING';
    return _buildStatusCapsule(
      icon: isPending ? Icons.check_circle : Icons.circle,
      iconColor: const Color(0xFF2E7D32),
      iconSize: isPending ? 14 : 6,
      backgroundColor: const Color(0xFFF7F7F7),
      text: isPending ? 'Pedido realizado' : 'Pedido em andamento',
      isBottom: true,
    );
  }

  Widget _buildStatusCapsule({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String text,
    double iconSize = 14,
    bool isBottom = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: Alignment.center, // Centered contents
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: isBottom 
          ? const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))
          : BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3F3E3E),
        ),
      ),
    );
  }

  Widget _buildConfirmArrivalCard(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 16, right: 16, top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seu pedido chegou?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Confirme quando receber pra gente saber se deu tudo certo',
            style: TextStyle(fontSize: 13, color: Color(0xFF717171)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showConfirmDeliveryModal(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEA1D2C)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirmar entrega',
                style: TextStyle(
                  color: Color(0xFFEA1D2C),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDeliveryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.delivery_dining,
                size: 80,
                color: Color(0xFFEA1D2C),
              ),
              const SizedBox(height: 24),
              const Text(
                'Você pode confirmar que recebeu seu pedido?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3F3E3E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Confirme quando receber pra gente saber se deu tudo certo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF717171)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(modalContext);

                    setState(() {
                      _hasJustConfirmed = true;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pedido recebido com sucesso',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: Color(0xFF2E7D32),
                        behavior: SnackBarBehavior.floating,
                        margin: EdgeInsets.all(16),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA1D2C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Sim, recebi meu pedido',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(modalContext),
                child: const Text(
                  'Voltar',
                  style: TextStyle(
                    color: Color(0xFFEA1D2C),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJustConfirmedWidget(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 48),
          const SizedBox(height: 12),
          const Text(
            'Seu pedido foi entregue',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Entregue às ${DateFormat('HH:mm').format(DateTime.now())}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF2E7D32)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicsSection(BuildContext context) {
    final isPending = _currentOrder.lastStatus.toUpperCase() == 'PENDING';

    final problemaPedidoOptions = isPending
        ? [
            _buildTopicItem(context, 'Não vou poder receber o pedido'),
            _buildTopicItem(context, 'Esqueci de inserir cupom'),
            _buildTopicItem(context, 'Horário de entrega muito tarde'),
            _buildTopicItem(context, 'Comprei sem querer'),
            _buildTopicItem(context, 'Meu pedido não foi confirmado'),
          ]
        : [
            _buildTopicItem(context, 'Adicionar informações ao pedido'),
            _buildTopicItem(context, 'Adicionar informações a entrega'),
            _buildTopicItem(context, 'Alterar endereço de entrega'),
            _buildTopicItem(context, 'Alterar itens do pedido'),
            _buildTopicItem(context, 'Não vou poder receber o pedido'),
            _buildTopicItem(context, 'Esqueci de inserir cupom'),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Se precisar, escolha outro tópico',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3F3E3E),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            iconColor: Colors.black,
            collapsedIconColor: Colors.black,
            leading: const Icon(Icons.receipt_long, color: Colors.black, size: 20),
            title: const Text(
              'Problema com Pedido',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3F3E3E),
              ),
            ),
            children: problemaPedidoOptions,
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            iconColor: Colors.black,
            collapsedIconColor: Colors.black,
            leading: const Icon(Icons.credit_card, color: Colors.black, size: 20),
            title: const Text(
              'Problema com pagamento',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3F3E3E),
              ),
            ),
            children: [
              _buildTopicItem(context, 'Preciso alterar a forma de pagamento'),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            iconColor: Colors.black,
            collapsedIconColor: Colors.black,
            leading: const Icon(Icons.description_outlined, color: Colors.black, size: 20),
            title: const Text(
              'Políticas',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3F3E3E),
              ),
            ),
            children: [
              _buildTopicItem(context, 'Política de cancelamento e reembolso'),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToTopic(BuildContext context, String title) {
    String description = '';
    TopicActionType actionType = TopicActionType.cancel;
    String buttonText = 'Solicitar cancelamento';
    IconData icon = Icons.info_outline;
    
    final isPending = _currentOrder.lastStatus.toUpperCase() == 'PENDING';

    switch (title) {
      case 'Não vou poder receber o pedido':
        if (isPending) {
          description = 'Descreva o problema para que a loja possa entender a sua situação';
          actionType = TopicActionType.submitForm;
          buttonText = 'Enviar';
          icon = Icons.delivery_dining;
        } else {
          description = 'Entendemos que imprevistos acontecem, mas não é possível cancelar um pedido que já está em preparo.\n\nLembre-se de sempre conferir os detalhes antes de finalizar o pedido.\n\nSe você não puder receber o pedido, fale com a loja pra solicitar o cancelamento.\n\nA loja vai analisar se consegue cancelar ou não e irá te responder em até 5 minutos.';
          actionType = TopicActionType.info;
          buttonText = 'Falar com a loja';
          icon = Icons.support_agent;
        }
        break;
      case 'Esqueci de inserir cupom':
        description = 'Não é possível fazer alterações depois que o pedido é feito. Como a loja ainda não iniciou o preparo, você pode cancelar e pedir novamente aplicando o cupom.\n\nSempre antes de fazer um pedido lembre-se de checar se o cupom foi aplicado corretamente, verifique as regras de uso e se todos os detalhes da sua compra estão de acordo com elas. Os cupons possuem limite de tempo e de utilizações.\n\nAlterar detalhes da compra depois de inserir um cupom pode invalidar seu benefício, por exemplo quando você troca a forma de pagamento.';
        actionType = TopicActionType.cancel;
        buttonText = 'Solicitar cancelamento';
        icon = Icons.local_activity;
        break;
      case 'Horário de entrega muito tarde':
        description = 'Descreva o problema para que a loja possa entender a sua situação';
        actionType = TopicActionType.submitForm;
        buttonText = 'Enviar';
        icon = Icons.access_time;
        break;
      case 'Comprei sem querer':
        description = 'Sentimos muito que isso seja um problema, você pode solicitar o cancelamento se desistir do seu pedido ou aguardar que ele chegará normalmente.';
        actionType = TopicActionType.cancel;
        buttonText = 'Solicitar cancelamento';
        icon = Icons.shopping_bag_outlined;
        break;
      case 'Meu pedido não foi confirmado':
        description = 'Quem faz a confirmação é o local em que você pediu e isso pode demorar alguns minutos. Se quiser, enquanto o pedido não for confirmado, você pode cancelar sem custos.';
        actionType = TopicActionType.cancel;
        buttonText = 'Solicitar cancelamento';
        icon = Icons.help_outline;
        break;
      case 'Preciso alterar a forma de pagamento':
        description = 'Não é possível alterar a forma de pagamento depois que o pedido foi feito. Caso queira, você pode cancelar e pedir de novo. Lembre-se de sempre verificar se a forma de pagamento que você quer usar está disponível na loja e de revisar os detalhes da compra antes de concluir seu pedido.';
        actionType = TopicActionType.cancel;
        buttonText = 'Solicitar cancelamento';
        icon = Icons.account_balance_wallet_outlined;
        break;
      case 'Adicionar informações ao pedido':
        description = 'Infelizmente não é possível modificar seu pedido após a confirmação dele. No entanto, você pode tentar entrar em contato com a loja para poder passar a observação diretamente a ele.';
        actionType = TopicActionType.info;
        buttonText = 'Falar com a loja';
        icon = Icons.edit_note;
        break;
      case 'Adicionar informações a entrega':
        description = 'Não conseguimos adicionar observações sobre a entrega depois que o pedido é feito. Sugerimos que você entre em contato com a loja pra verificar se é possível fazer a alteração que deseja.';
        actionType = TopicActionType.info;
        buttonText = 'Falar com a loja';
        icon = Icons.edit_location_alt_outlined;
        break;
      case 'Alterar endereço de entrega':
      case 'Alterar itens do pedido':
        description = 'Não é possível alterar detalhes como esse após o pedido já ter iniciado o preparo ou sido despachado. Recomendamos que entre em contato com a loja para verificar as opções.';
        actionType = TopicActionType.info;
        buttonText = 'Falar com a loja';
        icon = Icons.error_outline;
        break;
      case 'Política de cancelamento e reembolso':
        description = 'Você pode solicitar cancelamento sempre que o pedido ainda estiver PENDENTE para confirmação. Quando o pedido for ACEITO, o cancelamento só poderá ser feito entrando em acordo com a loja, via contato direto.\n\nO valor do reembolso voltará na mesma forma de pagamento utilizada assim que o cancelamento for aceito.';
        actionType = TopicActionType.info;
        buttonText = 'Entendi';
        icon = Icons.policy;
        break;
      default:
        description = 'Precisa de mais informações sobre "$title"?';
        break;
    }

    context.push('/order/${_currentOrder.shortId}/help/topic', extra: {
      'order': _currentOrder,
      'topicTitle': title,
      'description': description,
      'actionType': actionType,
      'buttonText': buttonText,
      'icon': icon,
    });
  }

  Widget _buildTopicItem(BuildContext context, String title) {
    return ListTile(
      dense: true, // More compact
      contentPadding: const EdgeInsets.only(left: 16, right: 12), // Adjusted to align chevron with expansion arrow
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF717171),
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
      onTap: () {
        _navigateToTopic(context, title);
      },
    );
  }

  Widget _buildStoreAvatar(String? logoUrl, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F2),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: logoUrl != null && logoUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: _formatImageUrl(logoUrl),
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorWidget: (_, __, ___) => const Icon(Icons.store, color: Colors.grey),
              )
            : const Icon(Icons.store, color: Colors.grey),
      ),
    );
  }

  String _formatImageUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://menuhub-dev.s3.us-east-1.amazonaws.com/$url';
  }
}
