const vowels=Object.fromEntries([... 'అఆఇఈఉఊఋౠఌౡఎఏఐఒఓఔ'].map((c,i)=>[c,['a','aa','i','ee','u','oo','ru','roo','lu','loo','e','e','ai','o','o','au'][i]]));
const consonants=Object.fromEntries([... 'కఖగఘఙచఛజఝఞటఠడఢణతథదధనపఫబభమయరఱలళవశషసహ'].map((c,i)=>[c,['k','kh','g','gh','ng','ch','chh','j','jh','ny','t','th','d','dh','n','t','th','d','dh','n','p','ph','b','bh','m','y','r','r','l','l','v','sh','sh','s','h'][i]]));
const signs=Object.fromEntries([... 'ాిీుూృౄౢౣెేైొోౌ'].map((c,i)=>[c,['aa','i','ee','u','oo','ru','roo','lu','loo','e','e','ai','o','o','au'][i]]));
export function transliterate(text){
  const chars=[...text.normalize('NFC')];let out='';
  for(let i=0;i<chars.length;i++){
    const c=chars[i],next=chars[i+1];
    if(consonants[c]){out+=consonants[c];if(next==='్')i++;else if(signs[next]){out+=signs[next];i++;}else out+='a';}
    else if(vowels[c]||signs[c])out+=vowels[c]||signs[c];
    else if(c==='ం')out+= !next||/\s/.test(next)||'పఫబభమ'.includes(next)?'m':'n';
    else if(c==='ఁ')out+='n';else if(c==='ః')out+='h';else if(c==='ఽ')out+="'";
    else if(c==='్'||c==='\u200c'||c==='\u200d')continue;
    else if(c>='౦'&&c<='౯')out+=String(c.codePointAt(0)-0x0c66);
    else out+=c;
  }
  return out;
}
