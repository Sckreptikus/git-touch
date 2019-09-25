import 'package:flutter/cupertino.dart';
import 'package:flutter_highlight/theme_map.dart';
import 'package:git_touch/models/code.dart';
import 'package:git_touch/scaffolds/refresh_stateful.dart';
import 'package:git_touch/screens/code_settings.dart';
import 'package:git_touch/screens/image_view.dart';
import 'package:git_touch/widgets/app_bar_title.dart';
import 'package:git_touch/widgets/link.dart';
import 'package:git_touch/widgets/markdown_view.dart';
import 'package:git_touch/widgets/table_view.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:git_touch/models/settings.dart';
import 'package:provider/provider.dart';
import 'package:git_touch/utils/utils.dart';
import 'package:primer/primer.dart';
import 'package:seti/seti.dart';

class ObjectScreen extends StatelessWidget {
  final String owner;
  final String name;
  final String branch;
  final List<String> paths;
  final String type;

  ObjectScreen({
    @required this.owner,
    @required this.name,
    @required this.branch,
    this.paths = const [],
    this.type = 'tree',
  });

  String get _expression => '$branch:' + paths.join('/');
  String get _extname {
    if (paths.isEmpty) return '';
    var dotext = path.extension(paths.last);
    if (dotext.isEmpty) return '';
    return dotext.substring(1);
  }

  String get _language => _extname.isEmpty ? 'plaintext' : _extname;

  String get rawUrl =>
      'https://raw.githubusercontent.com/$owner/$name/$branch/' +
      paths.join('/'); // TODO:

  static const _iconDefaultColor = PrimerColors.blue300;

  Widget _buildIcon(item) {
    switch (item['type']) {
      case 'blob':
        return SetiIcon(item['name'], size: 36);
      case 'tree':
      case 'commit':
        return Icon(
          item['type'] == 'tree'
              ? Octicons.file_directory
              : Octicons.file_submodule,
          color: _iconDefaultColor,
          size: 24,
        );
      default:
        throw 'Should not be here';
    }
  }

  String get _subQuery {
    switch (type) {
      case 'tree':
        return '''
... on Tree {
  entries {
    type
    name
  }
}
''';
      case 'blob':
      default:
        return '''
... on Blob {
  text
}
''';
    }
  }

  Widget _buildTree(payload) {
    var entries = payload['entries'] as List;
    return TableView(
      hasIcon: true,
      items: entries.map((item) {
        return TableViewItem(
          leftWidget: _buildIcon(item),
          text: Text(item['name']),
          screenBuilder: (_) {
            if (item['type'] == 'commit') return null;
            // TODO: All image types
            var ext = path.extension(item['name']);
            if (ext.isNotEmpty) ext = ext.substring(1);
            if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) {
              return ImageView(NetworkImage('$rawUrl/' + item['name']));
            }
            return ObjectScreen(
              name: name,
              owner: owner,
              branch: branch,
              paths: [...paths, item['name']],
              type: item['type'],
            );
          },
        );
      }),
    );
  }

  Widget _buildBlob(BuildContext context, payload) {
    var codeProvider = Provider.of<CodeModel>(context);
    switch (_extname) {
      case 'md':
      case 'markdown':
        return Padding(
          padding: const EdgeInsets.all(12),
          child: MarkdownView(payload['text']),
        );
      default:
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: HighlightView(
            payload['text'],
            language: _language,
            theme: themeMap[codeProvider.theme],
            padding: EdgeInsets.all(10),
            textStyle: TextStyle(
                fontSize: codeProvider.fontSize.toDouble(),
                fontFamily: codeProvider.fontFamilyUsed),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshStatefulScaffold(
      title: AppBarTitle(paths.join('/')),
      onRefresh: () async {
        var data = await Provider.of<SettingsModel>(context).query('''{
  repository(owner: "$owner", name: "$name") {
    object(expression: "$_expression") {
      $_subQuery
    }
  }
}''');

        if (type == 'tree') {
          var entries = data['repository']['object']['entries'] as List;
          entries.sort((a, b) {
            if (a['type'] == 'tree' && b['type'] == 'blob') {
              return -1;
            }
            if (a['type'] == 'blob' && b['type'] == 'tree') {
              return 1;
            }
            return 0;
          });
        }

        return data['repository']['object'];
      },
      trailingBuilder: (payload) {
        switch (type) {
          case 'blob':
            return Link(
              child: Icon(Octicons.settings, size: 20),
              material: false,
              screenBuilder: (_) =>
                  CodeSettingsScreen(payload['text'], _language),
            );
          default:
            return null;
        }
      },
      bodyBuilder: (payload) {
        switch (type) {
          case 'tree':
            return _buildTree(payload);
          case 'blob':
            return _buildBlob(context, payload);
          default:
            return null;
        }
      },
    );
  }
}
